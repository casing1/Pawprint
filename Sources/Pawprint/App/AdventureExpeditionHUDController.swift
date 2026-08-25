import AppKit
import Observation
import SwiftUI

/// Owns the ambient expedition's non-activating floating panel.
///
/// The panel object is reused so its screen position survives hiding, while its hosting
/// controller is deliberately released. Expedition lifetime belongs to
/// `AdventureExpeditionCenter`, not to this window or its SwiftUI tree.
@MainActor
@Observable
final class AdventureExpeditionHUDController {
    static let shared = AdventureExpeditionHUDController()

    static let compactContentSize = NSSize(width: 292, height: 302)
    static let expandedContentSize = NSSize(width: 480, height: 420)
    private static let screenMargin: CGFloat = 10

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var dragAnchor: (
        mouse: NSPoint,
        origin: NSPoint
    )?

    private(set) var isVisible = false
    private(set) var isExpanded = false
    private(set) var currentContentSize = compactContentSize

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Changes only the existing floating panel. It never opens or activates another window.
    func toggleExpanded() {
        isExpanded.toggle()

        guard let panel else {
            currentContentSize = desiredContentSize
            return
        }

        let screen = bestScreen(for: panel.frame)
        let nextSize = Self.fittedContentSize(
            desiredContentSize,
            within: screen?.visibleFrame
        )
        currentContentSize = nextSize

        let nextFrame = Self.frame(
            keepingTopRightOf: panel.frame,
            contentSize: nextSize,
            within: screen?.visibleFrame
        )
        panel.setFrame(nextFrame, display: true, animate: false)
        NSAccessibility.post(
            element: panel,
            notification: .layoutChanged
        )
    }

    /// Recreates the host on every show. The observable expedition center retains the actual run.
    func show() {
        let isNewPanel = panel == nil
        let panel = panel ?? makePanel()
        self.panel = panel

        let screen = isNewPanel
            ? (NSScreen.main ?? NSScreen.screens.first)
            : bestScreen(for: panel.frame)
        let contentSize = Self.fittedContentSize(
            desiredContentSize,
            within: screen?.visibleFrame
        )
        currentContentSize = contentSize

        if isNewPanel {
            panel.setFrame(
                NSRect(origin: .zero, size: contentSize),
                display: false
            )
            positionAtTopRight(panel, on: screen)
        } else {
            panel.setFrame(
                Self.frame(
                    keepingTopRightOf: panel.frame,
                    contentSize: contentSize,
                    within: screen?.visibleFrame
                ),
                display: false
            )
        }

        let hosting = NSHostingController(
            rootView: AdventureExpeditionHUDView()
        )
        hosting.view.frame = NSRect(
            origin: .zero,
            size: contentSize
        )

        panel.contentViewController = hosting
        panel.orderFrontRegardless()
        isVisible = true
    }

    /// Hiding never withdraws the run. The unanswered turn simply remains paused in the center.
    func hide() {
        dragAnchor = nil
        panel?.orderOut(nil)
        panel?.contentViewController = nil
        isVisible = false
    }

    // MARK: - Header dragging

    func dragToCurrentMouseLocation() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let anchor = dragAnchor ?? (mouse, panel.frame.origin)
        if dragAnchor == nil {
            dragAnchor = anchor
        }
        panel.setFrameOrigin(
            NSPoint(
                x: anchor.origin.x + mouse.x - anchor.mouse.x,
                y: anchor.origin.y + mouse.y - anchor.mouse.y
            )
        )
    }

    func endDrag() {
        dragAnchor = nil
    }

    /// Keeps the two independent Pawprint HUDs readable whichever one the user opens second.
    func avoidOverlap(with otherFrame: NSRect) {
        guard let panel, isVisible else { return }
        let clearance = otherFrame.insetBy(dx: -10, dy: -10)
        guard panel.frame.intersects(clearance) else { return }

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? panel.frame
        var origin = panel.frame.origin
        origin.y = otherFrame.minY - panel.frame.height - 10

        if origin.y < visible.minY + 10 {
            origin.y = min(
                visible.maxY - panel.frame.height - 10,
                otherFrame.maxY - panel.frame.height
            )
            origin.x = otherFrame.minX - panel.frame.width - 10
        }

        origin.x = max(
            visible.minX + 10,
            min(origin.x, visible.maxX - panel.frame.width - 10)
        )
        origin.y = max(
            visible.minY + 10,
            min(origin.y, visible.maxY - panel.frame.height - 10)
        )
        panel.setFrameOrigin(origin)
    }

    // MARK: - Panel

    private func makePanel() -> NSPanel {
        let contentRect = NSRect(
            origin: .zero,
            size: Self.compactContentSize
        )
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [
                .nonactivatingPanel,
                .borderless,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = Self.compactContentSize
        panel.contentMaxSize = Self.expandedContentSize
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        return panel
    }

    private var desiredContentSize: NSSize {
        isExpanded
            ? Self.expandedContentSize
            : Self.compactContentSize
    }

    private func positionAtTopRight(
        _ panel: NSPanel,
        on screen: NSScreen?
    ) {
        guard let screen else {
            return
        }
        let visible = screen.visibleFrame
        // The existing statistics HUD uses the same top-right anchor. Keep both useful when it is
        // already visible without reaching into its private panel frame or changing that window.
        let liveHUDClearance: CGFloat = LiveHUDController.shared.isVisible
            ? 230
            : 0
        panel.setFrameOrigin(
            NSPoint(
                x: visible.maxX - currentContentSize.width - 20,
                y: visible.maxY
                    - currentContentSize.height
                    - 20
                    - liveHUDClearance
            )
        )
    }

    private func bestScreen(for frame: NSRect) -> NSScreen? {
        let intersecting = NSScreen.screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(frame).area
                < rhs.visibleFrame.intersection(frame).area
        }
        if let intersecting,
           intersecting.visibleFrame.intersects(frame) {
            return intersecting
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Resizing keeps the HUD's top-right corner visually anchored, then repairs an off-screen
    /// position caused by a monitor being disconnected or its resolution changing.
    static func frame(
        keepingTopRightOf currentFrame: NSRect,
        contentSize: NSSize,
        within visibleFrame: NSRect?
    ) -> NSRect {
        var nextFrame = NSRect(
            x: currentFrame.maxX - contentSize.width,
            y: currentFrame.maxY - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )

        guard let visibleFrame else { return nextFrame }
        let minX = visibleFrame.minX + screenMargin
        let minY = visibleFrame.minY + screenMargin
        let maxX = visibleFrame.maxX - contentSize.width - screenMargin
        let maxY = visibleFrame.maxY - contentSize.height - screenMargin
        nextFrame.origin.x = max(minX, min(nextFrame.origin.x, maxX))
        nextFrame.origin.y = max(minY, min(nextFrame.origin.y, maxY))
        return nextFrame
    }

    static func fittedContentSize(
        _ desired: NSSize,
        within visibleFrame: NSRect?
    ) -> NSSize {
        guard let visibleFrame else { return desired }
        return NSSize(
            width: min(
                desired.width,
                max(
                    compactContentSize.width,
                    visibleFrame.width - screenMargin * 2
                )
            ),
            height: min(
                desired.height,
                max(
                    compactContentSize.height,
                    visibleFrame.height - screenMargin * 2
                )
            )
        )
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
