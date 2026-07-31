import Foundation

/// The four or five moments worth calling out about a day — the fastest minute, the longest stretch
/// of focus, the most scattered hour, the busiest minute and the application that took the most
/// time. Every one is a *time and a number*, never a description of what was being done.
package enum HighlightBuilder {

    package static func build(raw: DailyRawCounters, summary: DailySummary, dayStartHour: Int) -> [Highlight] {
        var items: [Highlight] = []

        if let time = summary.maxWPMTime, summary.maxWPM > 0 {
            items.append(Highlight(
                icon: "bolt.fill",
                title: L10n.t("statsEngine.0b7a9c1a"),
                detail: L10n.t("statsEngine.bcd12d08", Formatters.time(time), Formatters.wpm(summary.maxWPM))
            ))
        }

        if let longest = raw.focusSessions.max(by: { $0.duration < $1.duration }) {
            items.append(Highlight(
                icon: "target",
                title: L10n.t("statsEngine.ab2cbd75"),
                detail: L10n.t("statsEngine.2cb6382c", Formatters.time(longest.start), Formatters.longDuration(Int(longest.duration)), longest.primaryApp)
            ))
        }

        if let chaosMoment = chaosMoment(raw: raw, dayStartHour: dayStartHour) {
            items.append(Highlight(
                icon: "tornado",
                title: L10n.t("statsEngine.bfc623f3"),
                detail: chaosMoment
            ))
        }

        if let minute = summary.busiestMinute,
           summary.busiestMinuteCount >= 20,
           let time = DayKey.date(forMinute: minute, day: raw.day, dayStartHour: dayStartHour) {
            items.append(Highlight(
                icon: "flame",
                title: L10n.t("statsEngine.12de8b91"),
                detail: L10n.t("statsEngine.fda75cb4", Formatters.time(time), summary.busiestMinuteCount)
            ))
        }

        if let app = summary.topApp, app.totalSeconds >= 600 {
            items.append(Highlight(
                icon: "crown",
                title: L10n.t("statsEngine.c5325415"),
                detail: L10n.t("statsEngine.845a80a0", app.appName, Formatters.withObjectParticle(Formatters.longDuration(Int(app.totalSeconds))))
            ))
        }

        return items
    }

    private static func chaosMoment(raw: DailyRawCounters, dayStartHour: Int) -> String? {
        let calendar = Calendar.current
        var byHour: [Int: Int] = [:]
        for session in raw.appSessions {
            byHour[calendar.component(.hour, from: session.start), default: 0] += 1
        }
        if let peak = byHour.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }),
           peak.value >= 3 {
            return L10n.t("statsEngine.a2a40af5", Formatters.approximateHourLabel(peak.key), peak.value)
        }
        if let peakMinute = raw.activityPerMinute.enumerated().max(by: { $0.element < $1.element }),
           peakMinute.element > 0,
           let time = DayKey.date(forMinute: peakMinute.offset, day: raw.day, dayStartHour: dayStartHour) {
            return L10n.t("statsEngine.ff57f565", Formatters.time(time))
        }
        return nil
    }
}
