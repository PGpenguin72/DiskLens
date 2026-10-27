import SwiftUI
import RingwiseCore

/// Finder icon + name.
struct NameCell: View {
    let row: FileRow
    /// Chart color of this item, when it appears in the sunburst.
    var dotColor: Color? = nil
    /// Multi-select mode: whether the row is checked (`nil` hides the check circle).
    var checked: Bool? = nil
    var onToggle: () -> Void = {}

    // Table cells are hosted separately, so everything comes in as plain values — no @Environment here.
    var body: some View {
        HStack(spacing: 6) {
            if let checked {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(checked ? AnyShapeStyle(Theme.used) : AnyShapeStyle(.tertiary))
                    .contentShape(.rect)
                    .onTapGesture(perform: onToggle)
            }
            Circle()
                .fill(dotColor ?? .clear)
                .frame(width: 7, height: 7)
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
    var color: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule().fill(color.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(Theme.accentGradient))
                    .frame(width: max(fraction > 0 ? 2 : 0, 50 * fraction))
            }
            .frame(width: 50, height: 6)
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
            Text(row.modified, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                .help(row.modified.formatted(date: .complete, time: .shortened))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
    }
}
