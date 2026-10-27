import Darwin
import Foundation
import Synchronization

/// Parallel directory walker behind `Scanner`.
///
/// A shared LIFO stack of directories is drained by `threadCount` threads. Each thread reads a
/// whole directory with `getattrlistbulk`, hands it to the builder in one `addChildren` call and
/// pushes the subdirectories it should descend into.
final class ScanEngine: @unchecked Sendable {
    private struct Job {
        var path: String
        var id: NodeID
        /// Open parent directory, so the job can `openat` by name instead of resolving the full path.
        var parent: DirHandle?
        var name = ""
        var isRoot = false
    }

    private final class Counter { let value = Atomic<Int>(0) }

    /// Ref-counted directory fd, closed when the last child job holding it is gone.
    private final class DirHandle {
        let fd: Int32
        private let open: Counter
        init(fd: Int32, open: Counter) { self.fd = fd; self.open = open; open.value.add(1, ordering: .relaxed) }
        deinit { close(fd); open.value.subtract(1, ordering: .relaxed) }
    }

    private struct LinkKey: Hashable { var dev: Int32; var ino: UInt64 }

    private let builder: FileTreeBuilder
    private let excluded: Set<String>
    private let allowedDevices: Set<Int32>?
    private let progress: @Sendable (ScanProgress) -> Void
    private let threadCount: Int

    private let queue = NSCondition()
    private var stack: [Job] = []
    private var active = 0

    private let cancelled = Atomic<Bool>(false)
    private let items = Atomic<Int>(0)
    private let bytes = Atomic<Int64>(0)
    private let lastReport = Atomic<UInt64>(0)
    private let openHandles = Counter()
    private let maxHandles: Int
    private final class LinkShard { let lock = NSLock(); var seen: Set<LinkKey> = [] }
    private let hardLinks = (0..<16).map { _ in LinkShard() }

    init(root: String, options: ScanOptions, threadCount: Int, progress: @escaping @Sendable (ScanProgress) -> Void) {
        var st = stat()
        let rootStat = stat(root, &st) == 0 ? st : nil
        let mtime = rootStat.map { Double($0.st_mtimespec.tv_sec) + Double($0.st_mtimespec.tv_nsec) / 1e9 }
        builder = FileTreeBuilder(rootPath: root, rootModified: Date(timeIntervalSince1970: mtime ?? 0))
        excluded = options.excludedPaths
        self.progress = progress
        self.threadCount = max(1, threadCount)
        // Parent fds kept open for openat; stay well inside the soft limit (often just 256).
        var lim = rlimit()
        let soft = getrlimit(RLIMIT_NOFILE, &lim) == 0 ? Int(min(lim.rlim_cur, 1 << 20)) : 256
        maxHandles = max(0, soft / 2 - 32)
        if options.stayOnVolume, let rootStat {
            allowedDevices = Self.allowedDevices(rootDevice: rootStat.st_dev)
        } else {
            allowedDevices = nil
        }
        stack = [Job(path: root, id: NodeID(0), isRoot: true)]
    }

    /// The sealed System volume and the Data volume are one logical tree (joined by firmlinks),
    /// so a root on either of them may cross into the other. Everything else is a foreign mount.
    private static func allowedDevices(rootDevice: Int32) -> Set<Int32> {
        var devices: Set<Int32> = [rootDevice]
        var a = stat(), b = stat()
        if stat("/", &a) == 0, stat("/System/Volumes/Data", &b) == 0,
           rootDevice == a.st_dev || rootDevice == b.st_dev {
            devices.formUnion([a.st_dev, b.st_dev])
        }
        return devices
    }

    func cancel() {
        cancelled.store(true, ordering: .relaxed)
        queue.lock(); queue.broadcast(); queue.unlock()
    }

    /// Runs the scan on dedicated threads; returns the finished tree, or nil if cancelled.
    func run() async -> FileTree? {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for _ in 0..<threadCount {
                group.enter()
                let t = Thread { [self] in worker(); group.leave() }
                t.qualityOfService = .userInitiated
                t.start()
            }
            group.notify(queue: .global()) { cont.resume() }
        }
        if cancelled.load(ordering: .relaxed) { return nil }
        report(path: builder.rootPath, force: true)
        return builder.finish()
    }

    // MARK: Work queue

    private func nextJob() -> Job? {
        queue.lock(); defer { queue.unlock() }
        while true {
            if cancelled.load(ordering: .relaxed) { return nil }
            if let job = stack.popLast() { active += 1; return job }
            if active == 0 { queue.broadcast(); return nil }
            queue.wait()
        }
    }

    private func finishJob(pushing jobs: [Job]) {
        queue.lock(); defer { queue.unlock() }
        stack.append(contentsOf: jobs)
        active -= 1
        if jobs.count == 1 { queue.signal() } else if jobs.count > 1 || (active == 0 && stack.isEmpty) { queue.broadcast() }
    }

    private func worker() {
        let reader = BulkDirectoryReader()
        var raw: [RawEntry] = []
        while let job = nextJob() {
            let jobs = process(job, reader: reader, raw: &raw)
            finishJob(pushing: jobs)
        }
    }

    // MARK: Directory processing

    private func process(_ job: Job, reader: BulkDirectoryReader, raw: inout [RawEntry]) -> [Job] {
        let flags = O_RDONLY | O_DIRECTORY | O_CLOEXEC | (job.isRoot ? 0 : O_NOFOLLOW)
        var fd: Int32 = -1
        if let parent = job.parent { fd = openat(parent.fd, job.name, flags) }
        if fd < 0 && (job.parent == nil || errno == EMFILE || errno == ENFILE) { fd = open(job.path, flags) }
        guard fd >= 0 else { builder.markUnreadable(job.path); return [] }
        raw.removeAll(keepingCapacity: true)
        let err = reader.read(fd: fd, into: &raw)
        if err != 0 { builder.markUnreadable(job.path) }
        guard !raw.isEmpty else { close(fd); return [] }

        var entries: [FileTreeBuilder.Entry] = []
        entries.reserveCapacity(raw.count)
        var total: Int64 = 0
        for r in raw {
            var size: Int64 = 0
            if !r.isDirectory {
                size = r.allocatedSize
                if r.type == vreg, r.linkCount > 1, !firstSighting(dev: r.device, ino: r.inode) { size = 0 }
                total += size
            }
            var e = FileTreeBuilder.Entry(name: r.name, isDirectory: r.isDirectory, allocatedSize: size, modified: r.modified)
            e.isDataless = r.isDataless
            entries.append(e)
        }
        let ids = builder.addChildren(of: job.id, entries)

        var jobs: [Job] = []
        let base = job.path.hasSuffix("/") ? job.path : job.path + "/"
        for (i, r) in raw.enumerated() where r.isDirectory {
            let path = base + r.name
            if excluded.contains(path) || !shouldDescend(r, path: path) { continue }
            jobs.append(Job(path: path, id: ids[i], name: r.name))
        }
        if !jobs.isEmpty && openHandles.value.load(ordering: .relaxed) < maxHandles {
            let handle = DirHandle(fd: fd, open: openHandles)
            for i in jobs.indices { jobs[i].parent = handle }
        } else {
            close(fd)
        }

        items.add(raw.count, ordering: .relaxed)
        bytes.add(total, ordering: .relaxed)
        report(path: job.path, force: false)
        return jobs
    }

    private func shouldDescend(_ r: RawEntry, path: String) -> Bool {
        if r.isTrigger { return false }
        guard let allowed = allowedDevices else { return true }
        if !allowed.contains(r.device) { return false }
        if r.isMountPoint {
            // The entry describes the covered directory; stat crosses into the mounted file system.
            var st = stat()
            return lstat(path, &st) == 0 && allowed.contains(st.st_dev)
        }
        return true
    }

    private func firstSighting(dev: Int32, ino: UInt64) -> Bool {
        let key = LinkKey(dev: dev, ino: ino)
        let shard = hardLinks[Int(ino & 15)]
        shard.lock.lock(); defer { shard.lock.unlock() }
        return shard.seen.insert(key).inserted
    }

    private func report(path: String, force: Bool) {
        let now = DispatchTime.now().uptimeNanoseconds
        let last = lastReport.load(ordering: .relaxed)
        guard force || now &- last >= 100_000_000 else { return }
        guard lastReport.compareExchange(expected: last, desired: now, ordering: .relaxed).exchanged else { return }
        progress(ScanProgress(itemsScanned: items.load(ordering: .relaxed),
                              bytesScanned: bytes.load(ordering: .relaxed), currentPath: path))
    }
}
