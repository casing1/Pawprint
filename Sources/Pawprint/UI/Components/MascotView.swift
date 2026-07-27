import SwiftUI

enum MascotMood {
    case paused
    case idle
    case sprinting
    case typing
    case flustered
    case focused
    case clicking
    case scrolling
    case nightOwl
    case tired
    case neutral

    var emoji: String {
        switch self {
        case .paused: return "🙈"
        case .idle: return "😴"
        case .sprinting: return "🐆"
        case .typing: return "😸"
        case .flustered: return "🙀"
        case .focused: return "🧘"
        case .clicking: return "😼"
        case .scrolling: return "🌀"
        case .nightOwl: return "🦉"
        case .tired: return "😮‍💨"
        case .neutral: return "🐱"
        }
    }

    /// Shown next to the date, gives the mascot a voice without claiming to read the user's mind.
    var label: String {
        switch self {
        case .paused: return L10n.t("mascotView.732a4450")
        case .idle: return L10n.t("mascotView.9f075163")
        case .sprinting: return L10n.t("mascotView.93739fc8")
        case .typing: return L10n.t("mascotView.e858b921")
        case .flustered: return L10n.t("mascotView.bb1af037")
        case .focused: return L10n.t("mascotView.9f1822e9")
        case .clicking: return L10n.t("mascotView.a0771ecd")
        case .scrolling: return L10n.t("mascotView.7c387c2f")
        case .nightOwl: return L10n.t("mascotView.0df88534")
        case .tired: return L10n.t("mascotView.90bda5fe")
        case .neutral: return L10n.t("mascotView.02e81996")
        }
    }

    static func current(activityCenter: ActivityCenter) -> MascotMood {
        guard !activityCenter.settings.isPaused else { return .paused }
        guard activityCenter.isRecordingActive else { return .paused }

        let summary = activityCenter.todaySummary
        let wpm = activityCenter.liveWPM
        let secondsSinceActivity = summary.lastActivity.map { Date().timeIntervalSince($0) } ?? .greatestFiniteMagnitude

        if secondsSinceActivity > 180 { return .idle }

        if wpm >= 70 { return .sprinting }
        if wpm >= 25 { return .typing }

        if summary.totalKeyPresses > 50 && summary.backspaceRatio > 0.3 { return .flustered }

        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 1 && hour < 5 { return .nightOwl }

        if summary.activeSeconds > 8 * 3600 { return .tired }

        if let lastFocus = summary.longestFocusSeconds as Int?, lastFocus > 0,
           secondsSinceActivity < 60, summary.focusSessionCount > 0, wpm > 5 {
            return .focused
        }

        return .neutral
    }
}

struct MascotView: View {
    let mood: MascotMood
    var size: CGFloat = 40

    @State private var bounce = false

    var body: some View {
        Text(mood.emoji)
            .font(.system(size: size))
            .scaleEffect(bounce ? 1.08 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: bounce)
            .accessibilityLabel(mood.label)
            .onChange(of: mood.emoji) { _, _ in
                bounce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bounce = false }
            }
    }
}
