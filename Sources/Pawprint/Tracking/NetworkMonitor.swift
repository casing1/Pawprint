import Foundation

/// Tracks how much data crossed the network interfaces, using the kernel's per-interface byte
/// counters (`getifaddrs` → `if_data`). Requires no permission and reveals nothing about *what*
/// was transferred — no hosts, no ports, no packet contents — only totals.
@MainActor
final class NetworkMonitor: Monitor {
    var isRunning: Bool { timer != nil }

    private var timer: Timer?
    private var lastSample: (inBytes: UInt64, outBytes: UInt64)?

    /// Counters are cumulative since boot, so only deltas are meaningful.
    private static let sampleInterval: TimeInterval = 20

    func start() {
        guard timer == nil else { return }
        lastSample = Self.sample()
        let t = Timer(timeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-baselines without recording a delta. Used after wake, where the counters have kept
    /// running (or the interface reset) and the gap isn't attributable to today's usage.
    func resetBaseline() {
        lastSample = Self.sample()
    }

    private func poll() {
        let now = Self.sample()
        defer { lastSample = now }
        guard let previous = lastSample else { return }

        // A counter going backwards means the interface reset (sleep, Wi-Fi reconnect); skip
        // that interval rather than recording a wild negative-turned-huge value.
        guard now.inBytes >= previous.inBytes, now.outBytes >= previous.outBytes else { return }

        let deltaIn = now.inBytes - previous.inBytes
        let deltaOut = now.outBytes - previous.outBytes
        guard deltaIn > 0 || deltaOut > 0 else { return }

        ActivityCenter.shared.recordNetworkTraffic(
            downloadBytes: deltaIn,
            uploadBytes: deltaOut,
            overSeconds: Self.sampleInterval
        )
    }

    /// Sums byte counters across physical interfaces. Loopback, VPN tunnels (`utun`), bridges
    /// and virtual adapters are skipped so traffic isn't double-counted.
    private static func sample() -> (inBytes: UInt64, outBytes: UInt64) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, head != nil else { return (0, 0) }
        defer { freeifaddrs(head) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var pointer = head
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard current.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("ppp") else { continue }
            guard let data = current.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            totalIn += UInt64(data.pointee.ifi_ibytes)
            totalOut += UInt64(data.pointee.ifi_obytes)
        }
        return (totalIn, totalOut)
    }
}
