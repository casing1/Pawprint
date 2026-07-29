import Foundation

/// Turns raw numbers into things a person can actually picture.
///
/// Each line is self-contained — it names the quantity before the comparison, so the reader never
/// has to guess what "about 1.1 charges" refers to — but carries only *one* number. These are
/// analogies, not readouts; repeating the precise value in parentheses just adds noise.
///
/// Every fact is tagged with a `FunFact.Topic` so the UI can show a varied set instead of five
/// different ways of saying the same thing.
package enum FunConversions {

    // MARK: - Reference constants

    /// Energy references, in watt-hours (or watts, where the comparison is "how long could it run").
    private enum Energy {
        // Things you charge
        package static let smartphoneFullCharge = 15.0      // a modern phone battery
        package static let earbudsCaseCharge = 3.4          // wireless earbud case
        package static let smartwatchCharge = 1.2
        package static let aaBattery = 3.9

        // Things that draw power continuously (watts)
        package static let ledBulbWatts = 9.0               // 60W-equivalent LED
        package static let incandescentWatts = 60.0
        package static let routerWatts = 8.0
        package static let fanWatts = 50.0
        package static let electricBlanketWatts = 150.0
        package static let gameConsoleWatts = 150.0
        package static let vacuumWatts = 700.0
        package static let microwaveWatts = 1000.0
        package static let hairDryerWatts = 1200.0
        package static let airConditionerWatts = 1500.0
        package static let phoneVideoWatts = 1.5            // watching video on a phone

        // Things that take a fixed amount per use
        package static let riceCookerPerMeal = 150.0
        package static let washingMachinePerCycle = 500.0
        package static let refrigeratorPerDay = 1000.0
        package static let toastPerSlice = 25.0
        /// One 250ml cup from 20°C to 100°C ≈ 83.7kJ ≈ 23.3Wh
        package static let cupOfWaterBoil = 23.3
        package static let kettleOneLiter = 93.0

        // Getting around
        package static let evKmPerKWh = 6.5
        package static let eScooterWhPerKm = 15.0

        // Externalities
        /// Korean grid average, ~0.459 kg CO₂ per kWh.
        package static let gramsCO2PerKWh = 459.0
        /// A mature tree absorbs roughly 22kg CO₂ a year — about 2.5g an hour.
        package static let treeCO2GramsPerHour = 2.51
        /// Korean residential average, roughly 130 KRW per kWh.
        package static let krwPerKWh = 130.0
    }

    private enum Distance {
        package static let marathon = 42_195.0
        package static let trackLoop = 400.0
        package static let poolLength = 50.0
        package static let soccerField = 105.0
        package static let basketballCourt = 28.0
        package static let bowlingLane = 18.3
        package static let boeing747 = 70.0
        package static let seoulToBusan = 325_000.0
        package static let earthCircumference = 40_075_000.0
    }

    private enum Height {
        package static let buildingFloor = 3.2
        package static let stairStep = 0.18
        package static let namsanTower = 236.0
        package static let building63 = 249.0
        package static let eiffelTower = 330.0
        package static let lotteWorldTower = 555.0
        package static let hallasan = 1_947.0
        package static let baekdusan = 2_744.0
        package static let everest = 8_848.0
    }

    private enum Text {
        package static let a4CharsPerPage = 1_800.0
        package static let manuscriptSheet = 200.0        // 원고지 200자
        package static let kakaoMessage = 20.0
        package static let tweet = 280.0
        package static let shortNovel = 100_000.0
    }

    private enum Time {
        package static let movieMinutes = 110.0
        package static let ramenMinutes = 3.0
        package static let pomodoroMinutes = 25.0
        package static let songMinutes = 3.5
        package static let sitcomMinutes = 22.0
    }

    private enum Payload {
        package static let song = 4.0 * 1024 * 1024
        package static let photo = 3.5 * 1024 * 1024
        package static let floppy = 1.44 * 1024 * 1024
        package static let cd = 700.0 * 1024 * 1024
        package static let dvd = 4.7 * 1024 * 1024 * 1024
        package static let email = 75.0 * 1024
        package static let streamingPerHour1080p = 3.0 * 1024 * 1024 * 1024
        package static let streamingPerHour4K = 7.0 * 1024 * 1024 * 1024
    }

    /// Average finger travel between consecutive keys. Apple key pitch is ~19mm.
    private static let mmPerKeystroke = 30.0

    // MARK: - Helpers

    private static func meters(_ value: Double) -> String {
        value >= 1000
            ? String(format: "%.2fkm", value / 1000)
            : String(format: "%.0fm", value)
    }

    private static func count(_ value: Double) -> String {
        Formatters.groupedNumber(Int(value.rounded()))
    }

    private static func one(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func whole(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    /// Collects lines that share one subject and topic, each gated on its own threshold.
    private struct Builder {
        let topic: FunFact.Topic
        let subject: String
        var facts: [FunFact] = []

        mutating func add(when condition: Bool, _ predicate: String) {
            guard condition else { return }
            facts.append(FunFact(topic: topic, text: "\(subject) \(predicate)"))
        }
    }

    // MARK: - Energy

    /// Everyday equivalents for the energy the battery actually gave up today.
    ///
    /// Every comparison is gated on the *ratio being readable* rather than on a hand-tuned floor:
    /// "밥을 약 0.02번" and "전자레인지를 약 900,000초" are both technically true and both useless.
    /// One gate, applied uniformly, means a light day and a heavy day each surface a different
    /// handful of comparisons instead of the same two every time.
    static package func energyFacts(fromBatteryPercent percent: Int) -> [FunFact] {
        guard percent > 0, let wh = BatteryHardware.shared.wattHours(fromPercent: percent), wh > 0 else { return [] }
        let kWh = wh / 1000
        var b = Builder(topic: .energy, subject: L10n.t("funConversions.3ff56496", percent))

        /// Include a comparison only when the number in it is one a person can picture.
        func ratio(_ value: Double, low: Double = 0.25, high: Double = 20_000, _ text: (Double) -> String) {
            guard value >= low, value <= high else { return }
            b.add(when: true, text(value))
        }

        // Things you charge
        ratio(wh / Energy.smartphoneFullCharge) { L10n.t("funConversions.62f86a17", one($0)) }
        ratio(wh / Energy.earbudsCaseCharge) { L10n.t("funConversions.c4e73c5c", one($0)) }
        ratio(wh / Energy.smartwatchCharge) { L10n.t("funConversions.4a64291c", one($0)) }
        ratio(wh / Energy.aaBattery) { L10n.t("funConversions.e27a5f33", one($0)) }

        // Things that run for a while
        ratio(wh / Energy.ledBulbWatts) { L10n.t("funConversions.28de99a1", one($0)) }
        ratio(wh / Energy.incandescentWatts * 60) { L10n.t("funConversions.778d9714", whole($0)) }
        ratio(wh / Energy.routerWatts) { L10n.t("funConversions.460a7860", one($0)) }
        ratio(wh / Energy.fanWatts) { L10n.t("funConversions.09ac0e82", one($0)) }
        ratio(wh / Energy.electricBlanketWatts * 60) { L10n.t("funConversions.802a8b63", whole($0)) }
        ratio(wh / Energy.gameConsoleWatts * 60) { L10n.t("funConversions.657b9f61", whole($0)) }
        ratio(wh / Energy.vacuumWatts * 60) { L10n.t("funConversions.e9cced23", whole($0)) }
        ratio(wh / Energy.microwaveWatts * 3600) { L10n.t("funConversions.7d4ed3f7", whole($0)) }
        ratio(wh / Energy.hairDryerWatts * 60) { L10n.t("funConversions.80cbda01", whole($0)) }
        ratio(wh / Energy.airConditionerWatts * 60) { L10n.t("funConversions.49105687", whole($0)) }
        ratio(wh / Energy.phoneVideoWatts) { L10n.t("funConversions.efe5a015", one($0)) }

        // Things you do once
        ratio(wh / Energy.cupOfWaterBoil) { L10n.t("funConversions.140fbca1", one($0)) }
        ratio(wh / Energy.kettleOneLiter) { L10n.t("funConversions.110f73b1", one($0)) }
        ratio(wh / Energy.toastPerSlice) { L10n.t("funConversions.4cc7f549", one($0)) }
        ratio(wh / Energy.riceCookerPerMeal) { L10n.t("funConversions.6425e937", one($0)) }
        ratio(wh / Energy.washingMachinePerCycle) { L10n.t("funConversions.afade2fc", one($0)) }
        ratio(wh / Energy.refrigeratorPerDay * 24) { L10n.t("funConversions.ca3a4d1e", one($0)) }

        // Getting around
        ratio(kWh * Energy.evKmPerKWh * 1000, low: 30, high: 500_000) {
            $0 >= 1000
                ? L10n.t("funConversions.41097675", one($0 / 1000))
                : L10n.t("funConversions.18664f4f", whole($0))
        }
        ratio(wh / Energy.eScooterWhPerKm) { L10n.t("funConversions.71d37a56", one($0)) }

        // Externalities
        let grams = kWh * Energy.gramsCO2PerKWh
        ratio(grams, low: 1, high: 1_000_000) { L10n.t("funConversions.ee2798a2", whole($0)) }
        ratio(grams / Energy.treeCO2GramsPerHour, low: 1) {
            $0 >= 24
                ? L10n.t("funConversions.d4d8267f", one($0 / 24))
                : L10n.t("funConversions.70b8e455", whole($0))
        }
        ratio(kWh * Energy.krwPerKWh, low: 1, high: 1_000_000) { L10n.t("funConversions.832752df", whole($0)) }

        return b.facts
    }

    // MARK: - Keyboard

    static package func fingerTravelMeters(keystrokes: Int) -> Double {
        Double(keystrokes) * mmPerKeystroke / 1000
    }

    static package func keyboardFacts(characterKeys: Int, totalKeys: Int) -> [FunFact] {
        var facts: [FunFact] = []

        let travel = fingerTravelMeters(keystrokes: totalKeys)
        if totalKeys > 0, travel >= 1 {
            var b = Builder(topic: .typing, subject: L10n.t("funConversions.6256d28f"))
            b.add(when: true, L10n.t("funConversions.42a2582c", meters(travel)))
            b.add(when: travel / Distance.basketballCourt >= 0.5,
                  L10n.t("funConversions.68c1fa2f", one(travel / Distance.basketballCourt)))
            b.add(when: travel / Distance.soccerField >= 0.3,
                  L10n.t("funConversions.f24c151f", one(travel / Distance.soccerField)))
            b.add(when: travel / Distance.bowlingLane >= 1,
                  L10n.t("funConversions.d43dd052", whole(travel / Distance.bowlingLane)))
            facts += b.facts
        }

        guard characterKeys > 0 else { return facts }
        var t = Builder(topic: .text, subject: L10n.t("funConversions.1ac20bca", Formatters.groupedNumber(characterKeys)))
        t.add(when: Double(characterKeys) / Text.a4CharsPerPage >= 0.2,
              L10n.t("funConversions.8f5f2e35", one(Double(characterKeys) / Text.a4CharsPerPage)))
        t.add(when: Double(characterKeys) / Text.manuscriptSheet >= 1,
              L10n.t("funConversions.862e28fa", count(Double(characterKeys) / Text.manuscriptSheet)))
        t.add(when: Double(characterKeys) / Text.kakaoMessage >= 5,
              L10n.t("funConversions.5aff25fe", count(Double(characterKeys) / Text.kakaoMessage)))
        t.add(when: Double(characterKeys) / Text.tweet >= 3,
              L10n.t("funConversions.0937a4b6", count(Double(characterKeys) / Text.tweet)))
        t.add(when: Double(characterKeys) / Text.shortNovel * 100 >= 1,
              L10n.t("funConversions.27a3b1e4", whole(Double(characterKeys) / Text.shortNovel * 100)))
        return facts + t.facts
    }

    // MARK: - Cursor

    static package func cursorFacts(meters value: Double) -> [FunFact] {
        guard value >= 1 else { return [] }
        var b = Builder(topic: .cursor, subject: L10n.t("funConversions.a55d569f"))

        b.add(when: true, L10n.t("funConversions.42a2582c", meters(value)))
        b.add(when: value / Distance.bowlingLane >= 1,
              L10n.t("funConversions.d43dd052", whole(value / Distance.bowlingLane)))
        b.add(when: value / Distance.poolLength >= 1,
              L10n.t("funConversions.7390fcfd", one(value / Distance.poolLength / 2)))
        b.add(when: value / Distance.soccerField >= 0.5,
              L10n.t("funConversions.f24c151f", one(value / Distance.soccerField)))
        b.add(when: value / Distance.boeing747 >= 0.5,
              L10n.t("funConversions.e67883b9", one(value / Distance.boeing747)))
        b.add(when: value / Distance.trackLoop >= 0.3,
              L10n.t("funConversions.fc768e2c", one(value / Distance.trackLoop)))
        b.add(when: value / Distance.marathon * 100 >= 0.5,
              L10n.t("funConversions.5dab39f8", one(value / Distance.marathon * 100)))
        b.add(when: value / Distance.seoulToBusan * 100 >= 0.1,
              String(format: L10n.t("funConversions.8c82341c"), value / Distance.seoulToBusan * 100))
        b.add(when: value / Distance.earthCircumference * 100 >= 0.001,
              String(format: L10n.t("funConversions.fc5ba1b8"), value / Distance.earthCircumference * 100))
        return b.facts
    }

    // MARK: - Scroll

    static package func scrollFacts(screens: Double, screenHeightMeters: Double) -> [FunFact] {
        guard screens >= 0.5 else { return [] }
        let h = screens * screenHeightMeters
        var b = Builder(topic: .scroll, subject: L10n.t("funConversions.4ab67311", count(screens)))

        b.add(when: h / Height.stairStep >= 20, L10n.t("funConversions.ebd62fd4", count(h / Height.stairStep)))
        b.add(when: h / Height.buildingFloor >= 1, L10n.t("funConversions.44265811", whole(h / Height.buildingFloor)))
        b.add(when: h / Height.namsanTower * 100 >= 5, L10n.t("funConversions.e8938a1d", whole(h / Height.namsanTower * 100)))
        b.add(when: h / Height.building63 * 100 >= 5, L10n.t("funConversions.6da5b474", whole(h / Height.building63 * 100)))
        b.add(when: h / Height.eiffelTower * 100 >= 5, L10n.t("funConversions.aedf7161", whole(h / Height.eiffelTower * 100)))
        b.add(when: h / Height.lotteWorldTower * 100 >= 5, L10n.t("funConversions.9bbfbe7a", whole(h / Height.lotteWorldTower * 100)))
        b.add(when: h / Height.hallasan * 100 >= 2, L10n.t("funConversions.9e49a594", whole(h / Height.hallasan * 100)))
        b.add(when: h / Height.baekdusan * 100 >= 2, L10n.t("funConversions.234d1075", whole(h / Height.baekdusan * 100)))
        b.add(when: h / Height.everest * 100 >= 1, L10n.t("funConversions.90f861e0", one(h / Height.everest * 100)))
        return b.facts
    }

    // MARK: - Time

    static package func timeFacts(activeSeconds: Int, focusSeconds: Int, screenOnSeconds: Int) -> [FunFact] {
        guard activeSeconds > 60 else { return [] }
        let minutes = Double(activeSeconds) / 60
        var b = Builder(topic: .time, subject: L10n.t("funConversions.4c0f4d4d"))

        b.add(when: true, L10n.t("funConversions.b689ae61", Formatters.compactDuration(activeSeconds)))
        b.add(when: minutes / Time.movieMinutes >= 0.2,
              L10n.t("funConversions.bff2c14b", one(minutes / Time.movieMinutes)))
        b.add(when: minutes / Time.sitcomMinutes >= 1,
              L10n.t("funConversions.95d37de9", whole(minutes / Time.sitcomMinutes)))
        b.add(when: minutes / Time.songMinutes >= 5,
              L10n.t("funConversions.51c438cf", whole(minutes / Time.songMinutes)))
        b.add(when: minutes / Time.ramenMinutes >= 5,
              L10n.t("funConversions.9a1e80af", whole(minutes / Time.ramenMinutes)))
        b.add(when: minutes / (24 * 60) * 100 >= 5,
              L10n.t("funConversions.8623d04d", whole(minutes / (24 * 60) * 100)))

        var facts = b.facts
        let pomodoros = Double(focusSeconds) / 60 / Time.pomodoroMinutes
        if pomodoros >= 1 {
            facts.append(FunFact(topic: .focus,
                                 text: L10n.t("funConversions.8e8b13e7", one(pomodoros))))
        }
        if screenOnSeconds > activeSeconds, screenOnSeconds > 600 {
            let idle = screenOnSeconds - activeSeconds
            facts.append(FunFact(topic: .screen,
                                 text: L10n.t("funConversions.227e0c8c", Formatters.compactDuration(idle))))
        }
        return facts
    }

    // MARK: - Network

    static package func networkFacts(downloadBytes: UInt64, uploadBytes: UInt64, peakDownPerSec: Double) -> [FunFact] {
        let total = Double(downloadBytes) + Double(uploadBytes)
        guard total > 1024 * 1024 else { return [] }
        var b = Builder(topic: .network, subject: L10n.t("funConversions.38cb8fee"))

        b.add(when: true, L10n.t("funConversions.0be01953", Formatters.bytes(UInt64(total))))
        b.add(when: Double(downloadBytes) / Payload.streamingPerHour1080p >= 0.1,
              L10n.t("funConversions.c7749d4e", one(Double(downloadBytes) / Payload.streamingPerHour1080p)))
        b.add(when: Double(downloadBytes) / Payload.streamingPerHour4K >= 0.1,
              L10n.t("funConversions.85423555", one(Double(downloadBytes) / Payload.streamingPerHour4K)))
        b.add(when: total / Payload.song >= 5, L10n.t("funConversions.ae66c577", count(total / Payload.song)))
        b.add(when: total / Payload.photo >= 5, L10n.t("funConversions.e2ccfb48", count(total / Payload.photo)))
        b.add(when: total / Payload.email >= 50, L10n.t("funConversions.b7937890", count(total / Payload.email)))
        b.add(when: total / Payload.floppy >= 20, L10n.t("funConversions.e3a6b8c1", count(total / Payload.floppy)))
        b.add(when: total / Payload.cd >= 0.3, L10n.t("funConversions.f47908e4", one(total / Payload.cd)))
        b.add(when: total / Payload.dvd >= 0.2, L10n.t("funConversions.bbe91673", one(total / Payload.dvd)))

        var facts = b.facts
        if peakDownPerSec > 100 * 1024 {
            facts.append(FunFact(topic: .network,
                                 text: L10n.t("funConversions.33977165", Formatters.bytesPerSecond(peakDownPerSec))))
        }
        return facts
    }

    // MARK: - Pointer behaviour

    static package func clickFacts(totalClicks: Int, scrollDirectionChanges: Int, activeSeconds: Int) -> [FunFact] {
        var facts: [FunFact] = []
        if totalClicks >= 50 {
            facts.append(FunFact(topic: .pointer,
                                 text: L10n.t("funConversions.fa173ac3", Formatters.groupedNumber(totalClicks))))
            if activeSeconds > 600 {
                let perMinute = Double(totalClicks) / (Double(activeSeconds) / 60)
                facts.append(FunFact(topic: .pointer,
                                     text: L10n.t("funConversions.79d03d7d", one(perMinute))))
            }
        }
        if scrollDirectionChanges >= 30 {
            facts.append(FunFact(topic: .pointer,
                                 text: L10n.t("funConversions.df31798f", Formatters.groupedNumber(scrollDirectionChanges))))
        }
        return facts
    }
}
