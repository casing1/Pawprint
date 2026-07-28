import Foundation

enum Formatters {
    static func groupedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "8시간 42분" style long-form duration.
    static func longDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return L10n.t("formatters.4173ae55", h, m) }
        if h > 0 { return L10n.t("formatters.0967e5ff", h) }
        if m > 0 { return L10n.t("formatters.bfecc441", m) }
        return L10n.t("formatters.e1455aca", seconds)
    }

    /// "47m" / "1h 6m" compact form for menu bar and small cards.
    static func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func wpm(_ value: Double) -> String {
        String(format: "%.0f WPM", value)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        // `timeStyle`, not a fixed "a h:mm" pattern: the pattern pins the AM/PM marker to the
        // front, which is right for Korean and gives "AM 4:11" in English. A style lets the
        // locale decide both the order and the separator.
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = LocalizationManager.activeLocale
        return formatter.string(from: date)
    }

    /// Appends the correct Korean object particle (을/를) for the preceding word, chosen by
    /// whether its final syllable ends in a consonant. Without this, generated sentences read
    /// as "37분를" instead of "37분을".
    static func withObjectParticle(_ text: String) -> String {
        // Only Korean has the 을/를 distinction; other languages append nothing.
        guard LocalizationManager.usesMyriadGrouping else { return text }
        guard let last = text.unicodeScalars.last else { return text }
        // Hangul syllables occupy U+AC00...U+D7A3; (code - 0xAC00) % 28 == 0 means no final consonant.
        if last.value >= 0xAC00 && last.value <= 0xD7A3 {
            let hasFinalConsonant = (last.value - 0xAC00) % 28 != 0
            return text + (hasFinalConsonant ? L10n.t("formatters.90fb063b") : L10n.t("formatters.943d1aff"))
        }
        // Digits: pick by how the numeral is read aloud in Korean.
        if let digit = last.properties.numericValue, last.value < 128 {
            let endsInConsonantSound = [0, 1, 3, 6, 7, 8].contains(Int(digit))
            return text + (endsInConsonantSound ? L10n.t("formatters.90fb063b") : L10n.t("formatters.943d1aff"))
        }
        return text + L10n.t("formatters.90fb063b")
    }

    /// Abbreviates large counts so they can't overflow a narrow card.
    ///
    /// Uses the Korean myriad scale (만 = 10⁴, 억 = 10⁸) rather than K/M, since that's how these
    /// magnitudes are actually read here.
    ///
    /// Two things matter for a number that's meant to read as a *record*:
    ///  * Exact digits survive much longer than they used to. Anything under 100,000 prints in
    ///    full ("11,234"), because "1.1만" throws away the part that makes it feel earned and
    ///    "11,234" still fits every layout it appears in.
    ///  * Past that, the abbreviation keeps three significant figures ("12.3만", "123만") instead
    ///    of one decimal, so 11만 and 11.4만 stop collapsing onto the same string.
    ///
    /// The full value is never lost — `exactNumber` renders it, and the UI offers it on tap.
    static func compactNumber(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let n = abs(value)
        guard n >= 100_000 else { return sign + groupedNumber(n) }

        // The *scale* is locale-dependent, not just the suffix: Korean groups by myriads
        // (만 = 10⁴, 억 = 10⁸) while English groups by thousands. Swapping only the suffix would
        // label 123,000 as "12.3K".
        let units: [(scale: Double, suffix: String)] = LocalizationManager.usesMyriadGrouping
            ? [(10_000, L10n.t("formatters.63948d05")),
               (100_000_000, L10n.t("formatters.ed3c743d")),
               (1_000_000_000_000, L10n.t("formatters.7977ad75"))]
            : [(1_000, "K"), (1_000_000, "M"), (1_000_000_000, "B"), (1_000_000_000_000, "T")]
        var chosen = units[0]
        for unit in units where Double(n) >= unit.scale { chosen = unit }

        // Rounding can carry a value past the next unit's boundary: 99,999,999 rounds to 10000만,
        // which should read "1억". Re-bucket rather than print the carried digit.
        if let next = units.first(where: { $0.scale > chosen.scale }),
           significantValue(Double(n) / chosen.scale) * chosen.scale >= next.scale {
            chosen = next
        }
        return sign + significantText(Double(n) / chosen.scale) + chosen.suffix
    }

    /// Three significant figures: two decimals under 10, one under 100, none above.
    private static func significantDecimals(_ value: Double) -> Int {
        let magnitude = abs(value)
        return magnitude < 9.995 ? 2 : (magnitude < 99.95 ? 1 : 0)
    }

    private static func significantValue(_ value: Double) -> Double {
        let factor = pow(10.0, Double(significantDecimals(value)))
        return (value * factor).rounded() / factor
    }

    /// Three significant figures, trailing zeros dropped, thousands grouped ("1,235만").
    private static func significantText(_ value: Double) -> String {
        let decimals = significantDecimals(value)
        guard decimals > 0 else { return groupedNumber(Int(value.rounded())) }
        var text = String(format: "%.\(decimals)f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// The unabbreviated form, for the "show me the real number" affordance.
    static func exactNumber(_ value: Int) -> String { groupedNumber(value) }

    /// Every unit spelled out, for the same affordance applied to durations. `compactDuration`
    /// and `longSpan` both drop the smallest components once a span gets long.
    static func exactDuration(_ seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        var parts: [String] = []
        if days > 0 { parts.append(L10n.t("formatters.cec3694e", days)) }
        if hours > 0 { parts.append(L10n.t("formatters.0967e5ff", hours)) }
        if minutes > 0 { parts.append(L10n.t("formatters.bfecc441", minutes)) }
        if secs > 0 || parts.isEmpty { parts.append(L10n.t("formatters.e1455aca", secs)) }
        return parts.joined(separator: " ")
    }

    /// Three significant figures, with trailing zeros dropped ("12.0" → "12", "1.20" → "1.2").
    ///
    /// The bucket is chosen from the *rounded* value: 99.99 rounds to 100, and picking decimals
    /// from the unrounded number would print "100.0" instead of "100".
    private static func significant(_ value: Double) -> String {
        let magnitude = abs(value)
        let decimals = magnitude < 9.995 ? 2 : (magnitude < 99.95 ? 1 : 0)
        var text = String(format: "%.\(decimals)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }

    /// One decimal place, with a trailing ".0" dropped ("12.0" → "12").
    private static func trimmed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }

    /// Duration for long, accumulating spans. Past a day it switches to "3일 4시간" rather than
    /// letting the hour count grow without bound ("1,247h 3m").
    static func longSpan(_ seconds: Int) -> String {
        guard seconds >= 24 * 3600 else { return compactDuration(seconds) }
        let days = seconds / (24 * 3600)
        let hours = (seconds % (24 * 3600)) / 3600
        return hours > 0 ? L10n.t("formatters.8a9f57f9", days, hours) : L10n.t("formatters.cec3694e", days)
    }

    /// Distance that stays short whatever the magnitude.
    static func compactDistance(meters: Double) -> String {
        if meters >= 1_000_000 { return trimmed(meters / 1000) + "km" }
        if meters >= 1_000 { return String(format: "%.1fkm", meters / 1000) }
        return String(format: "%.0fm", meters)
    }

    static func bytes(_ value: UInt64) -> String {
        // ByteCountFormatter renders 0 as "Zero KB", which reads like a bug in a stats row.
        guard value > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(clamping: value))
    }

    /// Hours rendered so small and large values stay distinguishable: under an hour it drops to
    /// minutes, because "0.2시간 / 0.2시간" made a progress bar look stuck at its own target.
    static func hoursValue(_ hours: Double) -> String {
        if hours < 1 { return L10n.t("formatters.bfecc441", Int((hours * 60).rounded())) }
        if hours >= 100 { return compactNumber(Int(hours)) + L10n.t("formatters.6c35133c") }
        return String(format: L10n.t("formatters.3dd100c4"), hours)
    }

    static func bytesPerSecond(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return bytes(UInt64(value)) + "/s"
    }

    /// Renders a 24-hour clock hour as "오전 9시" / "오후 3시".
    ///
    /// The bare "15시대" form reads oddly in Korean — 시대 also means "era" — so hours are always
    /// spelled out with an 오전/오후 prefix.
    static func hourLabel(_ hour24: Int) -> String {
        let hour = ((hour24 % 24) + 24) % 24
        if hour == 0 { return L10n.t("formatters.c308f2aa") }
        if hour < 12 { return L10n.t("formatters.1de73f1f", hour) }
        if hour == 12 { return L10n.t("formatters.92e4ba2e") }
        return L10n.t("formatters.998e2965", hour - 12)
    }

    /// "오후 3시경" — for approximate, bucketed times.
    static func approximateHourLabel(_ hour24: Int) -> String {
        hourLabel(hour24) + L10n.t("formatters.30f39b92")
    }

    /// Korean weekday name for a 0-based index where 0 = Sunday.
    static func weekdayName(_ index: Int) -> String {
        let names = [L10n.t("formatters.06cf3e90"), L10n.t("formatters.75448692"), L10n.t("formatters.adb4a282"), L10n.t("formatters.c04eb2ef"), L10n.t("formatters.5664a634"), L10n.t("formatters.cf5632c7"), L10n.t("formatters.b9e40662")]
        guard index >= 0 && index < names.count else { return "?" }
        return names[index]
    }

    /// "12/06" — fits under a 62pt gallery thumbnail where the full label would truncate.
    static func shortDayLabel(_ day: String) -> String {
        guard let date = DayKey.date(fromDayString: day) else { return day }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.activeLocale
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    /// "2026. 3. 10." — for anything permanent, where the year is part of the fact.
    static func dayWithYearLabel(_ day: String) -> String {
        guard let date = DayKey.date(fromDayString: day) else { return day }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.activeLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func dayLabel(_ day: String) -> String {
        guard let date = DayKey.date(fromDayString: day) else { return day }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.activeLocale
        formatter.dateFormat = L10n.t("formatters.26ce67f8")
        return formatter.string(from: date)
    }
}
