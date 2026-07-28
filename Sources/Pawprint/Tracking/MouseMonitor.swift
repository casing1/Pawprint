import AppKit

/// Observes global mouse/trackpad events system-wide. Only relative motion deltas, click
/// counts, and scroll deltas are read — never on-screen coordinates or window/content info —
/// so nothing about what's on screen is ever observable.
///
/// `mouseMoved`/`scrollWheel` can fire at very high frequency, so raw deltas are accumulated
/// into a small lock-protected buffer and flushed into `ActivityCenter` on a fixed timer
/// instead of hopping to the main queue per event.
final class MouseMonitor {
    private var monitors: [Any] = []
    private var flushTimer: Timer?
    private let lock = NSLock()

    private var isDragging = false

    private var pendingDistance: Double = 0
    private var pendingDragDistance: Double = 0
    private var pendingMaxSpeed: Double = 0
    private var lastMoveTime: Date?

    private var pendingScrollDeltaY: Double = 0
    private var pendingScrollDeltaX: Double = 0
    private var pendingMaxScrollSpeed: Double = 0
    private var pendingScrollDirectionChanges: Int = 0
    private var lastScrollTime: Date?
    private var lastScrollSign: Int = 0

    func start() {
        guard monitors.isEmpty else { return }
        let mask: [NSEvent.EventTypeMask] = [
            .leftMouseDown, .rightMouseDown,
            .leftMouseUp, .rightMouseUp,
            .leftMouseDragged, .rightMouseDragged,
            .mouseMoved, .scrollWheel
        ]
        let combined = mask.reduce(into: NSEvent.EventTypeMask()) { $0.formUnion($1) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: combined, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(monitor)
        }

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.flush()
        }
        RunLoop.main.add(timer, forMode: .common)
        flushTimer = timer
    }

    /// Re-registers the monitors. Needed when Accessibility is granted after launch: a monitor
    /// created without it stays dead once it arrives.
    func restart() {
        stop()
        start()
    }

    func stop() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
        flushTimer?.invalidate()
        flushTimer = nil
        flush()
    }

    private func handle(_ event: NSEvent) {
        let now = Date()
        switch event.type {
        case .leftMouseDown:
            isDragging = false
            let isDouble = event.clickCount >= 2
            DispatchQueue.main.async {
                ActivityCenter.shared.recordClick(kind: isDouble ? .double : .left, at: now)
            }
        case .rightMouseDown:
            DispatchQueue.main.async {
                ActivityCenter.shared.recordClick(kind: .right, at: now)
            }
        case .leftMouseUp, .rightMouseUp:
            isDragging = false
        case .leftMouseDragged, .rightMouseDragged:
            let justStartedDragging = beginDragIfNeeded()
            if justStartedDragging {
                DispatchQueue.main.async {
                    ActivityCenter.shared.recordClick(kind: .drag, at: now)
                }
            }
            accumulateMovement(event, now: now, isDrag: true)
        case .mouseMoved:
            accumulateMovement(event, now: now, isDrag: false)
        case .scrollWheel:
            accumulateScroll(event, now: now)
        default:
            break
        }
    }

    private func beginDragIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isDragging { return false }
        isDragging = true
        return true
    }

    private func accumulateMovement(_ event: NSEvent, now: Date, isDrag: Bool) {
        let dx = event.deltaX
        let dy = event.deltaY
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0 else { return }
        lock.lock()
        pendingDistance += distance
        if isDrag { pendingDragDistance += distance }
        if let lastMoveTime, now.timeIntervalSince(lastMoveTime) > 0 {
            let speed = distance / now.timeIntervalSince(lastMoveTime)
            if speed > pendingMaxSpeed { pendingMaxSpeed = speed }
        }
        lastMoveTime = now
        lock.unlock()
    }

    /// Approximate on-screen height of one text line, used to convert a classic notched wheel's
    /// line-based delta into points so both device families accumulate in the same unit.
    private static let pointsPerScrollLine: Double = 16

    private func accumulateScroll(_ event: NSEvent, now: Date) {
        // Trackpads and Magic Mouse report precise deltas already in points; notched wheels
        // report lines. Without this distinction trackpad scrolling was over-counted ~16x.
        let scale = event.hasPreciseScrollingDeltas ? 1.0 : Self.pointsPerScrollLine
        let dy = Double(event.scrollingDeltaY) * scale
        let dx = Double(event.scrollingDeltaX) * scale
        lock.lock()
        pendingScrollDeltaY += dy
        pendingScrollDeltaX += dx
        let sign = dy > 0 ? 1 : (dy < 0 ? -1 : 0)
        if sign != 0 {
            if lastScrollSign != 0 && sign != lastScrollSign {
                pendingScrollDirectionChanges += 1
            }
            lastScrollSign = sign
        }
        if let lastScrollTime, now.timeIntervalSince(lastScrollTime) > 0 {
            let speed = abs(dy) / now.timeIntervalSince(lastScrollTime)
            if speed > pendingMaxScrollSpeed { pendingMaxScrollSpeed = speed }
        }
        lastScrollTime = now
        lock.unlock()
    }

    private func flush() {
        lock.lock()
        let distance = pendingDistance
        let maxSpeed = pendingMaxSpeed
        let scrollY = pendingScrollDeltaY
        let scrollX = pendingScrollDeltaX
        let maxScrollSpeed = pendingMaxScrollSpeed
        let dirChanges = pendingScrollDirectionChanges
        let dragDistance = pendingDragDistance
        pendingDistance = 0
        pendingDragDistance = 0
        pendingMaxSpeed = 0
        pendingScrollDeltaY = 0
        pendingScrollDeltaX = 0
        pendingMaxScrollSpeed = 0
        pendingScrollDirectionChanges = 0
        lock.unlock()

        guard distance > 0 || scrollY != 0 || scrollX != 0 || dirChanges > 0 else { return }
        let now = Date()
        if distance > 0 {
            ActivityCenter.shared.recordCursorMovement(distancePixels: distance, speedPxPerSec: maxSpeed, at: now)
        }
        if dragDistance > 0 {
            ActivityCenter.shared.recordDragDistance(points: dragDistance, at: now)
        }
        if scrollY != 0 || scrollX != 0 {
            ActivityCenter.shared.recordScroll(deltaY: scrollY, deltaX: scrollX, speedPointsPerSec: maxScrollSpeed, at: now)
        }
        for _ in 0..<dirChanges {
            ActivityCenter.shared.recordScrollDirectionChange(at: now)
        }
    }
}
