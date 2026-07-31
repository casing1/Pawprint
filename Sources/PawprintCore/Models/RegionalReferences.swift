import Foundation

/// The landmarks, currency and grid a comparison is measured against, chosen per language.
///
/// The fun conversions are analogies, and an analogy only works if the reader can picture the thing
/// on the other side of it. Every referent used to be Korean — Namsan Tower, Hallasan, Seoul to
/// Busan, won per kilowatt-hour — which is right for the language the app was written in and
/// useless in the other three.
///
/// Translating the *sentence* is not enough, and doing only that is worse than leaving it alone:
/// the number is computed against the referent's real measurement, so a German build that says
/// "Zugspitze" while dividing by Hallasan's 1,947 m is quietly wrong. The referent and its figure
/// have to move together, which is why they live here rather than in the language packs.
///
/// Two things are deliberately *not* regional. Everest and the Earth's circumference mean the same
/// thing everywhere, and so do the sporting distances — a marathon is 42.195 km in every country
/// that runs one.
package struct RegionalReferences: Equatable, Sendable {

    // MARK: - Heights, in metres

    /// Four structures, shortest to tallest. The bands matter more than the exact figures: each one
    /// is what makes a given amount of scrolling land on a readable percentage.
    package var towerSmall: Double
    package var towerMedium: Double
    package var towerLarge: Double
    package var towerHuge: Double

    /// A mountain you could climb in a day, and one you could not.
    package var mountainMedium: Double
    package var mountainLarge: Double

    // MARK: - Distance, in metres

    /// The intercity trip everyone in this locale has a feel for.
    package var intercityRoute: Double

    // MARK: - Energy

    /// Grid carbon intensity, grams of CO₂ per kilowatt-hour.
    package var gramsCO2PerKWh: Double

    /// Residential electricity price per kilowatt-hour, in whatever unit the pack's sentence names.
    ///
    /// The unit is minor-denomination where it has to be. A kilowatt-hour costs about 130 won but
    /// about 0.16 dollars, and "about 0.0 dollars of electricity" is not a fun fact — the reading
    /// gate would drop the line entirely. English and German therefore count cents, which puts all
    /// four locales in the same readable range.
    package var currencyPerKWh: Double

    // MARK: - Text

    /// Characters on one sheet of whatever this locale writes drafts on.
    package var manuscriptSheetChars: Double

    // MARK: - The four

    /// South Korea. The original set, unchanged — every figure the app has ever shipped came from
    /// here, and the Korean numbers have to stay exactly what they were.
    package static let korean = RegionalReferences(
        towerSmall: 236,          // N Seoul Tower
        towerMedium: 249,         // 63 Building
        towerLarge: 330,          // Eiffel Tower
        towerHuge: 555,           // Lotte World Tower
        mountainMedium: 1_947,    // Hallasan
        mountainLarge: 2_744,     // Baekdusan
        intercityRoute: 325_000,  // Seoul to Busan
        gramsCO2PerKWh: 459,
        currencyPerKWh: 130,      // KRW
        manuscriptSheetChars: 200)  // 원고지 200자

    /// English. Deliberately not one country's set: the pack is read in Britain, America and
    /// everywhere else that defaults to English, so the landmarks are the ones that need no
    /// introduction in any of them.
    package static let english = RegionalReferences(
        towerSmall: 96,           // Big Ben
        towerMedium: 184,         // Space Needle
        towerLarge: 330,          // Eiffel Tower
        towerHuge: 443,           // Empire State Building, to the tip
        mountainMedium: 1_345,    // Ben Nevis
        mountainLarge: 2_917,     // Mount Olympus
        intercityRoute: 344_000,  // London to Paris
        gramsCO2PerKWh: 386,      // US grid average
        currencyPerKWh: 16,       // US cents
        manuscriptSheetChars: 200)  // an index card

    package static let japanese = RegionalReferences(
        towerSmall: 108,          // 通天閣
        towerMedium: 296,         // 横浜ランドマークタワー
        towerLarge: 333,          // 東京タワー
        towerHuge: 634,           // 東京スカイツリー
        mountainMedium: 1_592,    // 阿蘇山（高岳）
        mountainLarge: 3_776,     // 富士山
        intercityRoute: 515_000,  // 東京から大阪
        gramsCO2PerKWh: 470,
        currencyPerKWh: 31,       // 円
        manuscriptSheetChars: 400)  // 原稿用紙は一枚 400 字

    package static let german = RegionalReferences(
        towerSmall: 110,          // Elbphilharmonie
        towerMedium: 157,         // Kölner Dom
        towerLarge: 259,          // Commerzbank Tower
        towerHuge: 368,           // Berliner Fernsehturm
        mountainMedium: 1_493,    // Feldberg
        mountainLarge: 2_962,     // Zugspitze
        intercityRoute: 585_000,  // Berlin nach München
        gramsCO2PerKWh: 380,
        currencyPerKWh: 35,       // Cent
        manuscriptSheetChars: 200)  // eine Postkarte

    package static func forLanguage(_ code: String) -> RegionalReferences {
        switch code {
        case "ko": return .korean
        case "ja": return .japanese
        case "de": return .german
        default: return .english
        }
    }

    /// Follows the active language pack, so the referent and the sentence naming it never disagree.
    package static var current: RegionalReferences { forLanguage(Tables.resolvedCode) }
}
