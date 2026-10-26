import AppKit
import ObjectiveC
import SwiftUI

/// Makes every scroll view in the app use thin, auto-hiding overlay scrollers, even when System Settings
/// says "Always show scroll bars" — the legacy scroller with its track breaks the glass cards.
enum OverlayScrollerStyle {
    /// Call once before any window is created. Scroll views read `NSScroller.preferredScrollerStyle`
    /// whenever they are built or the system preference changes, so overriding it covers every
    /// table SwiftUI rebuilds later.
    static func install() {
        guard let method = class_getClassMethod(NSScroller.self, #selector(getter: NSScroller.preferredScrollerStyle)) else { return }
        let overlay: @convention(block) (AnyObject) -> NSScroller.Style = { _ in .overlay }
        method_setImplementation(method, imp_implementationWithBlock(overlay))
    }
}

extension View {
    /// Removes the table's horizontal scroller and header corner filler (a dark square next to the header).
    func overlayScrollers() -> some View {
        background(TableChromeCleaner())
    }
}

private struct TableChromeCleaner: NSViewRepresentable {
    func makeNSView(context: Context) -> CleanerView { CleanerView() }
    func updateNSView(_ view: CleanerView, context: Context) { view.scheduleApply() }

    final class CleanerView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleApply()
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
                if scrollView.hasHorizontalScroller { scrollView.hasHorizontalScroller = false }
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
