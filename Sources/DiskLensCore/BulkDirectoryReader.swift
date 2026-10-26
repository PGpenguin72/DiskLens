import Darwin

/// One directory entry as returned by `getattrlistbulk(2)`.
struct RawEntry {
    var name: String
    var type: UInt32          // fsobj_type_t (VREG, VDIR, VLNK…)
    var device: Int32
    var inode: UInt64
    var linkCount: UInt32     // files only
    var allocatedSize: Int64  // files only
    var modified: Double
    var flags: UInt32         // st_flags
    var mountStatus: UInt32   // directories only

    var isDirectory: Bool { type == vdir }
    var isMountPoint: Bool { mountStatus & 0x1 != 0 }     // DIR_MNTSTATUS_MNTPOINT
    var isTrigger: Bool { mountStatus & 0x2 != 0 }        // DIR_MNTSTATUS_TRIGGER (autofs)
    var isDataless: Bool { flags & 0x4000_0000 != 0 }     // SF_DATALESS
}

let vreg: UInt32 = 1, vdir: UInt32 = 2

/// Reads whole directories with `getattrlistbulk`. One reader per thread (owns its buffer).
final class BulkDirectoryReader {
    private static let cmnName: UInt32 = 0x1, cmnDevID: UInt32 = 0x2, cmnObjType: UInt32 = 0x8,
        cmnModTime: UInt32 = 0x400, cmnFlags: UInt32 = 0x4_0000, cmnFileID: UInt32 = 0x200_0000,
        cmnError: UInt32 = 0x2000_0000, cmnReturned: UInt32 = 0x8000_0000
    private static let dirMountStatus: UInt32 = 0x4
    private static let fileLinkCount: UInt32 = 0x1, fileAllocSize: UInt32 = 0x4

    private var attrs: attrlist
    private let bufSize = 256 * 1024
    private let buf: UnsafeMutableRawPointer

    init() {
        attrs = attrlist()
        attrs.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrs.commonattr = Self.cmnReturned | Self.cmnError | Self.cmnName | Self.cmnDevID | Self.cmnObjType
            | Self.cmnModTime | Self.cmnFlags | Self.cmnFileID
        attrs.dirattr = Self.dirMountStatus
        attrs.fileattr = Self.fileLinkCount | Self.fileAllocSize
        buf = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 16)
    }

    deinit { buf.deallocate() }

    /// Reads all entries of the open directory `fd`, appending to `out`.
    /// Returns 0 on success, or the errno that stopped the read (entries read so far are kept).
    func read(fd: Int32, into out: inout [RawEntry]) -> Int32 {
        while true {
            let n = getattrlistbulk(fd, &attrs, buf, bufSize, 0)
            if n == 0 { return 0 }
            if n < 0 {
                if errno == EINTR { continue }
                return errno
            }
            var p = UnsafeRawPointer(buf)
            for _ in 0..<n {
                let length = Int(p.loadUnaligned(as: UInt32.self))
                if let e = Self.parse(p) { out.append(e) }
                p += length
            }
        }
    }

    private static func parse(_ start: UnsafeRawPointer) -> RawEntry? {
        var p = start + 4
        // attribute_set_t: common, vol, dir, file, fork
        let rCommon = p.loadUnaligned(as: UInt32.self)
        let rDir = p.loadUnaligned(fromByteOffset: 8, as: UInt32.self)
        let rFile = p.loadUnaligned(fromByteOffset: 12, as: UInt32.self)
        p += 20
        if rCommon & cmnError != 0 { p += 4 }  // per-entry error: keep whatever attributes came back
        guard rCommon & cmnName != 0 else { return nil }
        let nameOff = Int(p.loadUnaligned(as: Int32.self))
        let nameLen = Int(p.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
        let nameBytes = UnsafeRawBufferPointer(start: p + nameOff, count: max(0, nameLen - 1))
        let name = String(decoding: nameBytes, as: UTF8.self)
        p += 8
        var e = RawEntry(name: name, type: 0, device: 0, inode: 0, linkCount: 1, allocatedSize: 0,
                         modified: 0, flags: 0, mountStatus: 0)
        if rCommon & cmnDevID != 0 { e.device = p.loadUnaligned(as: Int32.self); p += 4 }
        if rCommon & cmnObjType != 0 { e.type = p.loadUnaligned(as: UInt32.self); p += 4 }
        if rCommon & cmnModTime != 0 {
            let sec = p.loadUnaligned(as: Int.self), nsec = p.loadUnaligned(fromByteOffset: 8, as: Int.self)
            e.modified = Double(sec) + Double(nsec) / 1e9
            p += 16
        }
        if rCommon & cmnFlags != 0 { e.flags = p.loadUnaligned(as: UInt32.self); p += 4 }
        if rCommon & cmnFileID != 0 { e.inode = p.loadUnaligned(as: UInt64.self); p += 8 }
        if rDir & dirMountStatus != 0 { e.mountStatus = p.loadUnaligned(as: UInt32.self); p += 4 }
        if rFile & fileLinkCount != 0 { e.linkCount = p.loadUnaligned(as: UInt32.self); p += 4 }
        if rFile & fileAllocSize != 0 { e.allocatedSize = p.loadUnaligned(as: Int64.self); p += 8 }
        return e
    }
}
