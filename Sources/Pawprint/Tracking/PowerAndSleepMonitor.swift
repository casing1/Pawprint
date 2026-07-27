import AppKit
import CoreAudio
import IOKit
import IOKit.ps

/// Observes everything about the Mac's own state rather than the user's input:
/// system sleep/wake, display sleep, screen lock/unlock, lid (clamshell) open/close,
/// battery level and charge sessions, power source, low-power mode and thermal pressure,
/// external display connections, and audio output device switches.
///
/// None of this requires Accessibility or Input Monitoring — it's all public state APIs.
final class PowerAndSleepMonitor {
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private var powerRunLoopSource: CFRunLoopSource?
    private var stateTimer: Timer?

    private var lastSleepAt: Date?
    private var wasOnACPower: Bool?
    private var lastBatteryLevel: Int?
    private var isChargeSessionOpen = false

    private var lidClosed: Bool?
    private var lidClosedAt: Date?

    private var lastStateSampleAt: Date?
    private var knownScreenCount: Int = 0
    private var audioListenerInstalled = false

    /// Whether the display is currently lit and unlocked. Flipped by display sleep/wake, screen
    /// lock/unlock, and system sleep/wake; the slow sampler bills elapsed time against it.
    private var screenIsOn = true

    private func setScreenOn(_ on: Bool) {
        guard on != screenIsOn else { return }
        // Bank the time accrued under the previous state before switching.
        flushScreenOnTime()
        screenIsOn = on
    }

    private var lastScreenSampleAt: Date?

    private func flushScreenOnTime(at now: Date = Date()) {
        defer { lastScreenSampleAt = now }
        guard screenIsOn, let last = lastScreenSampleAt else { return }
        let elapsed = Int(now.timeIntervalSince(last))
        guard elapsed > 0 else { return }
        // Clamp so an unnoticed sleep can't dump hours into the total at once.
        ActivityCenter.shared.accumulateScreenOnTime(
            seconds: min(elapsed, Int(Self.stateSampleInterval * 3)),
            at: now
        )
    }

    /// How often power/thermal/lid state is sampled. Deliberately coarse — these change slowly
    /// and each sample crosses into the kernel or CoreAudio.
    private static let stateSampleInterval: TimeInterval = 15

    func start() {
        let wsnc = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            wsnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleSleep()
            },
            wsnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleWake()
            },
            wsnc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.setScreenOn(false)
                ActivityCenter.shared.recordDisplaySleep()
            },
            wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.setScreenOn(true)
                ActivityCenter.shared.recordDisplayWake()
            },
        ]

        let dnc = DistributedNotificationCenter.default()
        distributedObservers = [
            dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                // A locked screen is still lit, but it isn't "your screen" in any useful sense,
                // so it stops counting toward screen-on time.
                self?.setScreenOn(false)
                ActivityCenter.shared.recordMacState(SleepWakeRecord(type: .screenLock, timestamp: Date()))
            },
            dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                self?.setScreenOn(true)
                ActivityCenter.shared.recordMacState(SleepWakeRecord(type: .screenUnlock, timestamp: Date()))
            },
        ]

        knownScreenCount = NSScreen.screens.count
        ActivityCenter.shared.recordDisplayChange(connected: 0, disconnected: 0, totalDisplays: knownScreenCount)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }

        setupPowerSourceMonitoring()
        setupAudioMonitoring()

        lidClosed = Self.readClamshellClosed()
        sampleBattery()
        lastStateSampleAt = Date()
        lastScreenSampleAt = Date()

        let timer = Timer(timeInterval: Self.stateSampleInterval, repeats: true) { [weak self] _ in
            self?.sampleSlowState()
        }
        RunLoop.main.add(timer, forMode: .common)
        stateTimer = timer
    }

    func stop() {
        let wsnc = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { wsnc.removeObserver($0) }
        workspaceObservers.removeAll()

        let dnc = DistributedNotificationCenter.default()
        distributedObservers.forEach { dnc.removeObserver($0) }
        distributedObservers.removeAll()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        stateTimer?.invalidate()
        stateTimer = nil

        if let source = powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            powerRunLoopSource = nil
        }
        teardownAudioMonitoring()
    }

    // MARK: - Sleep / wake

    private func handleSleep() {
        lastSleepAt = Date()
        setScreenOn(false)
        ActivityCenter.shared.recordMacState(SleepWakeRecord(type: .sleep, timestamp: Date()))
    }

    private func handleWake() {
        let now = Date()
        let duration = lastSleepAt.map { Int(now.timeIntervalSince($0)) } ?? 0
        ActivityCenter.shared.recordMacState(SleepWakeRecord(type: .wake, timestamp: now, durationSeconds: duration))
        lastSleepAt = nil
        // A lid close that put the Mac to sleep is only half an event until it is reopened, and
        // reopening is what wakes it. Silently re-baselining here meant every close on a laptop
        // with no external display was counted while its matching open never was.
        //
        // Only our own tracked state is consulted, never a clamshell read at the sleep boundary:
        // those proved unreliable and produced phantom close/open pairs for ordinary idle sleep.
        // Since an open is only counted when we previously saw a genuine close, a phantom would
        // need a phantom close first.
        countLidOpenIfPending()
        resyncLidBaseline()
        sampleBattery()
        // Time spent asleep shouldn't be billed to battery/AC or screen-on usage.
        lastStateSampleAt = now
        lastScreenSampleAt = now
        screenIsOn = true
    }

    // MARK: - Lid (clamshell)

    /// Reads the lid state from IOKit. Returns nil on desktop Macs, which have no clamshell.
    private static func readClamshellClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let prop = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        let value = prop.takeRetainedValue()
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue
    }

    /// Counts the open half of a close/open pair that straddled a sleep. No-op when the lid was
    /// already open — that is ordinary idle sleep, not a lid action.
    private func countLidOpenIfPending() {
        guard lidClosed == true, Self.readClamshellClosed() == false else { return }
        let closedFor = lidClosedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        lidClosedAt = nil
        lidClosed = false
        ActivityCenter.shared.recordLidChange(closed: false, closedForSeconds: closedFor)
    }

    /// Adopts the current lid state as the new baseline without counting a transition. Used after
    /// wake, where we can't tell what actually happened while the machine was asleep.
    private func resyncLidBaseline() {
        if let closedNow = Self.readClamshellClosed() {
            lidClosed = closedNow
            if !closedNow { lidClosedAt = nil }
        }
    }

    /// Counts lid transitions observed while the Mac is awake: clamshell mode (lid closed with an
    /// external display attached), reopening, and a close the 15s poll happens to catch in the
    /// moment before the machine goes down.
    ///
    /// Deliberately not called at the sleep boundary. Reads there misreport, and a phantom close
    /// recorded on the way down would now produce a phantom open on the way back up.
    private func checkLid() {
        guard let closedNow = Self.readClamshellClosed() else { return }
        guard closedNow != lidClosed else { return }
        let previous = lidClosed
        lidClosed = closedNow

        // Skip the very first observation — it's the starting state, not a user action.
        guard previous != nil else { return }

        if closedNow {
            lidClosedAt = Date()
            ActivityCenter.shared.recordLidChange(closed: true)
        } else {
            let closedFor = lidClosedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
            lidClosedAt = nil
            ActivityCenter.shared.recordLidChange(closed: false, closedForSeconds: closedFor)
        }
    }

    // MARK: - Displays

    private func handleScreenChange() {
        DisplayMetrics.shared.recompute()
        let newCount = NSScreen.screens.count
        let delta = newCount - knownScreenCount
        knownScreenCount = newCount
        guard delta != 0 else { return }
        ActivityCenter.shared.recordDisplayChange(
            connected: delta > 0 ? delta : 0,
            disconnected: delta < 0 ? -delta : 0,
            totalDisplays: newCount
        )
    }

    // MARK: - Slow state sampling

    private func sampleSlowState() {
        let now = Date()
        let elapsed = lastStateSampleAt.map { Int(now.timeIntervalSince($0)) } ?? 0
        lastStateSampleAt = now

        flushScreenOnTime(at: now)
        checkLid()

        let info = ProcessInfo.processInfo
        let elevatedThermal = info.thermalState != .nominal
        // `wasOnACPower` is kept current by the IOKit power-source callback.
        let onAC = wasOnACPower ?? true

        // Guard against a wildly large delta (e.g. after an unnoticed sleep) skewing totals.
        let boundedElapsed = min(elapsed, Int(Self.stateSampleInterval * 3))
        ActivityCenter.shared.accumulatePowerTime(
            seconds: boundedElapsed,
            onAC: onAC,
            lowPowerMode: info.isLowPowerModeEnabled,
            elevatedThermal: elevatedThermal,
            at: now
        )
    }

    // MARK: - Power source / battery

    private func setupPowerSourceMonitoring() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            Unmanaged<PowerAndSleepMonitor>.fromOpaque(context).takeUnretainedValue().sampleBattery()
        }
        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource(callback, context) else { return }
        let source = unmanagedSource.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerRunLoopSource = source
    }

    private func sampleBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let firstSource = sources.first else { return }
        guard let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: AnyObject] else { return }

        let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? -1
        let powerState = description[kIOPSPowerSourceStateKey] as? String
        let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
        let isOnAC = (powerState == kIOPSACPowerValue)
        let now = Date()

        if let wasOnACPower, wasOnACPower != isOnAC {
            ActivityCenter.shared.recordMacState(
                SleepWakeRecord(type: isOnAC ? .chargerConnect : .chargerDisconnect, timestamp: now)
            )
            if isOnAC {
                if capacity >= 0 {
                    ActivityCenter.shared.beginChargeSession(startLevel: capacity, at: now)
                    isChargeSessionOpen = true
                }
            } else if isChargeSessionOpen {
                ActivityCenter.shared.endChargeSession(endLevel: capacity >= 0 ? capacity : (lastBatteryLevel ?? 0), at: now)
                isChargeSessionOpen = false
            }
        }
        wasOnACPower = isOnAC

        if capacity >= 0 {
            // Only record a sample when the level actually moved, so the stored timeline stays
            // compact instead of one entry per callback.
            if lastBatteryLevel != capacity {
                lastBatteryLevel = capacity
                ActivityCenter.shared.recordBatterySample(
                    BatterySample(timestamp: now, level: capacity, isCharging: isCharging)
                )
            }
        }
    }

    // MARK: - Audio output device

    private var audioAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private func setupAudioMonitoring() {
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &audioAddress,
            audioListenerProc,
            nil
        )
        audioListenerInstalled = (status == noErr)
    }

    private func teardownAudioMonitoring() {
        guard audioListenerInstalled else { return }
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &audioAddress,
            audioListenerProc,
            nil
        )
        audioListenerInstalled = false
    }
}

/// Top-level C function pointer — CoreAudio listeners can't capture context in Swift closures
/// that carry state, so this hops straight to the shared `ActivityCenter` on the main queue.
private let audioListenerProc: AudioObjectPropertyListenerProc = { _, _, _, _ in
    DispatchQueue.main.async {
        ActivityCenter.shared.recordAudioOutputChange()
    }
    return noErr
}
