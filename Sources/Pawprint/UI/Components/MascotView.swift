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
        case .paused: return "기록을 잠시 멈췄어요"
        case .idle: return "조용히 기다리고 있어요"
        case .sprinting: return "엄청 빠르게 타이핑 중!"
        case .typing: return "열심히 타이핑 중"
        case .flustered: return "수정이 좀 많네요"
        case .focused: return "집중 모드예요"
        case .clicking: return "클릭이 바쁘네요"
        case .scrolling: return "한참 스크롤 중"
        case .nightOwl: return "밤이 깊었어요"
        case .tired: return "오늘 많이 달렸어요"
        case .neutral: return "평소처럼 사용 중"
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
