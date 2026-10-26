import AppKit
import SwiftUI

extension View {
    /// Gives the tables in this window thin, auto-hiding overlay scrollers without a track, even when
    /// System Settings says "Always show scroll bars" — the legacy scroller breaks the glass look.
    func overlayScrollers() -> some View {
        background(OverlayScrollerInstaller())
    }
}

private struct OverlayScrollerInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> InstallerView { InstallerView() }
    func updateNSView(_ view: InstallerView, context: Context) { view.scheduleApply() }

    final class InstallerView: NSView {
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleApply()
            if observer == nil {
                // AppKit resets the style when the system preference changes.
                observer = NotificationCenter.default.addObserver(
                    forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main
                ) { [weak self] _ in self?.scheduleApply() }
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        /// SwiftUI builds the table's scroll view lazily, so apply on the next run loop turns.
        func scheduleApply() {
            for delay in [0.0, 0.3] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.apply() }
            }
        }

        private func apply() {
            guard let root = window?.contentView else { return }
            for scrollView in Self.tableScrollViews(in: root) {
                if scrollView.scrollerStyle != .overlay { scrollView.scrollerStyle = .overlay }
                scrollView.autohidesScrollers = true
                if scrollView.hasHorizontalScroller { scrollView.hasHorizontalScroller = false }
                // The header's corner filler shows as a dark square above the (now overlay) scroller.
                if let table = scrollView.documentView as? NSTableView, table.cornerView != nil { table.cornerView = nil }
            }
        }

        private static func tableScrollViews(in view: NSView) -> [NSScrollView] {
            var found: [NSScrollView] = []
            if let scrollView = view as? NSScrollView, scrollView.documentView is NSTableView {
                found.append(scrollView)
            }
            for sub in view.subviews { found += tableScrollViews(in: sub) }
            return found
        }
    }
}
