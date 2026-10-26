import SwiftUI
import DiskLensCore

/// Finder icon + name.
struct NameCell: View {
    let row: FileRow

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: IconCache.shared.icon(name: row.name, path: row.path, isDirectory: row.isDirectory))
                .resizable()
                .frame(width: 16, height: 16)
            Text(row.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct SizeCell: View {
    let size: Int64

    var body: some View {
        Text(ByteFormat.string(size))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Size relative to the containing folder.
struct SizeBarCell: View {
    let fraction: Double

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(Color.accentColor)
                    .frame(width: max(fraction > 0 ? 2 : 0, 70 * fraction))
            }
            .frame(width: 70, height: 6)
            Text(fraction, format: .percent.precision(.fractionLength(fraction < 0.1 ? 1 : 0)))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

struct CountCell: View {
    let row: FileRow

    var body: some View {
        Group {
            if row.isDirectory {
                Text(row.fileCount, format: .number)
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct DateCell: View {
    let row: FileRow

    var body: some View {
        if row.hasKnownDate {
            Text(row.modified, format: .dateTime.year().month(.twoDigits).day(.twoDigits).hour().minute())
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
    }
}
