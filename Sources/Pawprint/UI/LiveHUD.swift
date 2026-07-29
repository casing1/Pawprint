import AppKit
import SwiftUI
import PawprintCore

/// Floating always-on-top readout of the session happening right now.
///
/// The appeal is watching numbers move: a WPM needle that responds as you type, a focus timer
/// that keeps climbing. Everything here is already tracked — this just puts it somewhere you can
/// see it without opening the popover.
@MainActor
struct LiveHUDView: View {
    @Bindable var activityCenter = ActivityCenter.shared

    /// Ticks the clock-based readouts, which change without any input arriving.
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var summary: DailySummary { activityCenter.todaySummary }
    private var settings: AppSettings { activityCenter.settings }
    private var isCompact: Bool { settings.hudCompact }

    /// Opacity lives here rather than in Settings: you can only judge how see-through the panel
    /// should be by looking at it against whatever is behind it right now.
    @State private var showingOpacity: Bool

    /// The opacity row starts hidden; the parameter exists so layout can be rendered in both
    /// states without driving the button.
    init(showingOpacity: Bool = false) {
        _showingOpacity = State(initialValue: showingOpacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 5 : 8) {
            header
            if showingOpacity {
                opacityControl
            }
            gauge
            if !isCompact {
                stats
            }
        }
        .padding(isCompact ? 8 : 10)
        .frame(width: isCompact ? 132 : 190)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        // Applied to the whole panel rather than the window so the material backing fades too.
        .opacity(settings.hudOpacity)
        // Dragging the panel is a gesture on the container, not `isMovableByWindowBackground`.
        // With the window-level behaviour, AppKit consumed the mouse-down before the opacity bar
        // ever saw it, so dragging the bar moved the HUD instead of changing the value. SwiftUI
        // resolves gestures innermost-first, so the bar's own drag now wins over this one.
        .gesture(windowDrag)
        .onReceive(clock) { now = $0 }
        .onChange(of: showingOpacity) {
            // `fittingSize` is only correct once SwiftUI has laid out the new row.
            DispatchQueue.main.async { LiveHUDController.shared.refreshSize() }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: activityCenter.isRecordingActive ? "pawprint.fill" : "pawprint")
                .font(.system(size: 9))
                .foregroundStyle(Color.accentColor)
            if !isCompact {
                Text(L10n.t("liveHUD.b7a78a5a")).font(.caption2.weight(.semibold))
            }
            Spacer(minLength: 2)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showingOpacity.toggle() }
            } label: {
                Image(systemName: showingOpacity ? "circle.righthalf.filled" : "circle.lefthalf.filled")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showingOpacity ? Color.accentColor : Color.secondary.opacity(0.7))
            .help(L10n.t("liveHUD.3885d542"))

            Button {
                activityCenter.setHUDCompact(!isCompact)
            } label: {
                Image(systemName: isCompact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help(isCompact ? L10n.t("liveHUD.5eec8827") : L10n.t("liveHUD.35a0c359"))

            Button {
                LiveHUDController.shared.hide()
            } label: {
                Image(systemName: "xmark").font(.system(size: 8))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help(L10n.t("liveHUD.94b7dba1"))
        }
    }

    /// Screen-space drag that repositions the panel.
    ///
    /// Uses `NSEvent.mouseLocation` rather than the gesture's translation: the window moves while
    /// you drag it, so window-relative coordinates chase themselves and the panel judders.
    private var windowDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in LiveHUDController.shared.dragToCurrentMouseLocation() }
            .onEnded { _ in LiveHUDController.shared.endDrag() }
    }

    /// Inline opacity row. Floor is 0.35 — below that the digits stop being legible against a busy
    /// desktop, which defeats the point of the panel.
    private var opacityControl: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.min").font(.system(size: 8)).foregroundStyle(.tertiary)
            OpacityBar(value: activityCenter.binding(\.hudOpacity), range: 0.35...1.0)
                .frame(height: 10)
            Text("\(Int(settings.hudOpacity * 100))")
                .font(.system(size: 8).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// WPM needle. Scaled to 120 WPM so a fast burst still has headroom to climb into.
    private var gauge: some View {
        let wpm = activityCenter.liveWPM
        let fraction = min(wpm / 120, 1)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(wpm))")
                    .font(.system(size: isCompact ? 19 : 26, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("WPM").font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                if isCompact {
                    Text(Formatters.compactDuration(activityCenter.sessionSeconds))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * fraction))
                }
            }
            .frame(height: isCompact ? 4 : 5)
            .animation(.easeOut(duration: 0.35), value: fraction)
        }
    }

    /// Session rows plus whichever today-metrics the user picked in settings.
    private var stats: some View {
        VStack(spacing: 4) {
            if settings.hudShowsSessionTime {
                row(L10n.t("liveHUD.046d22be"), Formatters.compactDuration(activityCenter.sessionSeconds))
            }
            if settings.hudShowsSessionKeys {
                row(L10n.t("liveHUD.567fb32a"), Formatters.compactNumber(activityCenter.sessionKeyPresses))
            }
            if settings.hudShowsSessionClicks {
                row(L10n.t("liveHUD.ec433402"), Formatters.compactNumber(activityCenter.sessionClicks))
            }

            let metrics = settings.hudMetricIDs.compactMap { MetricCatalog.metric(id: $0) }
            if !metrics.isEmpty {
                Divider().opacity(0.4)
                ForEach(metrics) { metric in
                    row(metric.title, metric.display(summary))
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .contentTransition(.numericText())
        }
    }
}

/// Owns the floating HUD window.
///
/// Uses a non-activating `NSPanel` so clicking it never steals focus from whatever you're
/// working in — the whole point is to glance at it mid-task.
@MainActor
final class LiveHUDController: NSObject, NSWindowDelegate {
    static let shared = LiveHUDController()

    private var panel: NSPanel?
    private(set) var isVisible = false

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Compact mode changes the intrinsic size, so the panel has to be re-fitted to its content.
    func refreshSize() {
        guard let panel, let hosting = panel.contentViewController else { return }
        let fitted = hosting.view.fittingSize
        guard fitted.width > 0, fitted.height > 0 else { return }
        var frame = panel.frame
        // Keep the top-right corner anchored so the panel doesn't appear to jump when it shrinks.
        let right = frame.maxX
        let top = frame.maxY
        frame.size = fitted
        frame.origin = NSPoint(x: right - fitted.width, y: top - fitted.height)
        panel.setFrame(frame, display: true, animate: true)
    }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            isVisible = true
            return
        }

        let hosting = NSHostingController(rootView: LiveHUDView())
        hosting.view.frame = NSRect(x: 0, y: 0, width: 190, height: 200)

        let panel = NSPanel(
            contentRect: hosting.view.frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        // Off: it steals mouse-downs from the controls inside. `windowDrag` moves the panel instead.
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        // Follow the user across Spaces — a HUD that vanishes when you switch desktop is useless.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        positionAtTopRight(panel)
        self.panel = panel

        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    // MARK: - Dragging

    /// Mouse position and panel origin captured at the start of the current drag.
    private var dragAnchor: (mouse: NSPoint, origin: NSPoint)?

    func dragToCurrentMouseLocation() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let anchor = dragAnchor ?? (mouse, panel.frame.origin)
        if dragAnchor == nil { dragAnchor = anchor }
        panel.setFrameOrigin(NSPoint(
            x: anchor.origin.x + (mouse.x - anchor.mouse.x),
            y: anchor.origin.y + (mouse.y - anchor.mouse.y)
        ))
    }

    func endDrag() { dragAnchor = nil }

    private func positionAtTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - size.width - 20,
            y: visible.maxY - size.height - 20
        ))
    }
}

/// A minimal drag-to-set bar.
///
/// Deliberately not a `Slider`: the HUD lives in a `.nonactivatingPanel` that never becomes key,
/// and an AppKit-backed control there is a gamble. A plain shape plus a drag gesture behaves the
/// same whether or not the window has focus, and reads better at 10pt tall than a mini slider.
@MainActor
struct OpacityBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - range.lowerBound) / span)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.25))
                Capsule()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: max(3, width * fraction))
                Circle()
                    .fill(.white)
                    .shadow(radius: 1)
                    .frame(width: geo.size.height, height: geo.size.height)
                    .offset(x: max(0, min(width - geo.size.height, width * fraction - geo.size.height / 2)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0 else { return }
                        let ratio = min(1, max(0, drag.location.x / width))
                        value = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}
