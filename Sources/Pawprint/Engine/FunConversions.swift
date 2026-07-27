import Foundation

/// Turns raw numbers into things a person can actually picture.
///
/// Each line is self-contained — it names the quantity before the comparison, so the reader never
/// has to guess what "about 1.1 charges" refers to — but carries only *one* number. These are
/// analogies, not readouts; repeating the precise value in parentheses just adds noise.
///
/// Every fact is tagged with a `FunFact.Topic` so the UI can show a varied set instead of five
/// different ways of saying the same thing.
enum FunConversions {

    // MARK: - Reference constants

    /// Energy references, in watt-hours (or watts, where the comparison is "how long could it run").
    private enum Energy {
        // Things you charge
        static let smartphoneFullCharge = 15.0      // a modern phone battery
        static let earbudsCaseCharge = 3.4          // wireless earbud case
        static let smartwatchCharge = 1.2
        static let aaBattery = 3.9

        // Things that draw power continuously (watts)
        static let ledBulbWatts = 9.0               // 60W-equivalent LED
        static let incandescentWatts = 60.0
        static let routerWatts = 8.0
        static let fanWatts = 50.0
        static let electricBlanketWatts = 150.0
        static let gameConsoleWatts = 150.0
        static let vacuumWatts = 700.0
        static let microwaveWatts = 1000.0
        static let hairDryerWatts = 1200.0
        static let airConditionerWatts = 1500.0
        static let phoneVideoWatts = 1.5            // watching video on a phone

        // Things that take a fixed amount per use
        static let riceCookerPerMeal = 150.0
        static let washingMachinePerCycle = 500.0
        static let refrigeratorPerDay = 1000.0
        static let toastPerSlice = 25.0
        /// One 250ml cup from 20°C to 100°C ≈ 83.7kJ ≈ 23.3Wh
        static let cupOfWaterBoil = 23.3
        static let kettleOneLiter = 93.0

        // Getting around
        static let evKmPerKWh = 6.5
        static let eScooterWhPerKm = 15.0

        // Externalities
        /// Korean grid average, ~0.459 kg CO₂ per kWh.
        static let gramsCO2PerKWh = 459.0
        /// A mature tree absorbs roughly 22kg CO₂ a year — about 2.5g an hour.
        static let treeCO2GramsPerHour = 2.51
        /// Korean residential average, roughly 130 KRW per kWh.
        static let krwPerKWh = 130.0
    }

    private enum Distance {
        static let marathon = 42_195.0
        static let trackLoop = 400.0
        static let poolLength = 50.0
        static let soccerField = 105.0
        static let basketballCourt = 28.0
        static let bowlingLane = 18.3
        static let boeing747 = 70.0
        static let seoulToBusan = 325_000.0
        static let earthCircumference = 40_075_000.0
    }

    private enum Height {
        static let buildingFloor = 3.2
        static let stairStep = 0.18
        static let namsanTower = 236.0
        static let building63 = 249.0
        static let eiffelTower = 330.0
        static let lotteWorldTower = 555.0
        static let hallasan = 1_947.0
        static let baekdusan = 2_744.0
        static let everest = 8_848.0
    }

    private enum Text {
        static let a4CharsPerPage = 1_800.0
        static let manuscriptSheet = 200.0        // 원고지 200자
        static let kakaoMessage = 20.0
        static let tweet = 280.0
        static let shortNovel = 100_000.0
    }

    private enum Time {
        static let movieMinutes = 110.0
        static let ramenMinutes = 3.0
        static let pomodoroMinutes = 25.0
        static let songMinutes = 3.5
        static let sitcomMinutes = 22.0
    }

    private enum Payload {
        static let song = 4.0 * 1024 * 1024
        static let photo = 3.5 * 1024 * 1024
        static let floppy = 1.44 * 1024 * 1024
        static let cd = 700.0 * 1024 * 1024
        static let dvd = 4.7 * 1024 * 1024 * 1024
        static let email = 75.0 * 1024
        static let streamingPerHour1080p = 3.0 * 1024 * 1024 * 1024
        static let streamingPerHour4K = 7.0 * 1024 * 1024 * 1024
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
    static func energyFacts(fromBatteryPercent percent: Int) -> [FunFact] {
        guard percent > 0, let wh = BatteryHardware.shared.wattHours(fromPercent: percent), wh > 0 else { return [] }
        let kWh = wh / 1000
        var b = Builder(topic: .energy, subject: "오늘 쓴 배터리 \(percent)%는")

        /// Include a comparison only when the number in it is one a person can picture.
        func ratio(_ value: Double, low: Double = 0.25, high: Double = 20_000, _ text: (Double) -> String) {
            guard value >= low, value <= high else { return }
            b.add(when: true, text(value))
        }

        // Things you charge
        ratio(wh / Energy.smartphoneFullCharge) { "스마트폰을 약 \(one($0))번 충전할 수 있는 전력이에요" }
        ratio(wh / Energy.earbudsCaseCharge) { "무선 이어폰 케이스를 약 \(one($0))번 충전할 수 있는 양이에요" }
        ratio(wh / Energy.smartwatchCharge) { "스마트워치를 약 \(one($0))번 충전할 수 있는 전력이에요" }
        ratio(wh / Energy.aaBattery) { "AA 건전지 약 \(one($0))개에 담긴 에너지예요" }

        // Things that run for a while
        ratio(wh / Energy.ledBulbWatts) { "LED 전구 하나를 약 \(one($0))시간 켜둘 수 있는 전력이에요" }
        ratio(wh / Energy.incandescentWatts * 60) { "옛날 백열등을 약 \(whole($0))분 켤 수 있는 양이에요" }
        ratio(wh / Energy.routerWatts) { "와이파이 공유기를 약 \(one($0))시간 돌릴 수 있는 전력이에요" }
        ratio(wh / Energy.fanWatts) { "선풍기를 약 \(one($0))시간 돌릴 수 있는 양이에요" }
        ratio(wh / Energy.electricBlanketWatts * 60) { "전기장판을 약 \(whole($0))분 켤 수 있는 전력이에요" }
        ratio(wh / Energy.gameConsoleWatts * 60) { "게임 콘솔을 약 \(whole($0))분 돌릴 수 있는 양이에요" }
        ratio(wh / Energy.vacuumWatts * 60) { "청소기를 약 \(whole($0))분 돌릴 수 있는 전력이에요" }
        ratio(wh / Energy.microwaveWatts * 3600) { "전자레인지를 약 \(whole($0))초 돌릴 수 있는 양이에요" }
        ratio(wh / Energy.hairDryerWatts * 60) { "헤어드라이어를 약 \(whole($0))분 쓸 수 있는 전력이에요" }
        ratio(wh / Energy.airConditionerWatts * 60) { "에어컨을 약 \(whole($0))분 켤 수 있는 양이에요" }
        ratio(wh / Energy.phoneVideoWatts) { "스마트폰으로 영상을 약 \(one($0))시간 볼 수 있는 전력이에요" }

        // Things you do once
        ratio(wh / Energy.cupOfWaterBoil) { "물 한 컵을 약 \(one($0))번 끓일 수 있는 양이에요" }
        ratio(wh / Energy.kettleOneLiter) { "전기포트로 물 1L를 약 \(one($0))번 끓일 수 있는 전력이에요" }
        ratio(wh / Energy.toastPerSlice) { "식빵을 약 \(one($0))장 구울 수 있는 양이에요" }
        ratio(wh / Energy.riceCookerPerMeal) { "밥을 약 \(one($0))번 지을 수 있는 전력이에요" }
        ratio(wh / Energy.washingMachinePerCycle) { "세탁기를 약 \(one($0))번 돌릴 수 있는 양이에요" }
        ratio(wh / Energy.refrigeratorPerDay * 24) { "냉장고를 약 \(one($0))시간 돌릴 수 있는 전력이에요" }

        // Getting around
        ratio(kWh * Energy.evKmPerKWh * 1000, low: 30, high: 500_000) {
            $0 >= 1000
                ? "전기차로 약 \(one($0 / 1000))km 갈 수 있는 전력이에요"
                : "전기차로 약 \(whole($0))m 갈 수 있는 전력이에요"
        }
        ratio(wh / Energy.eScooterWhPerKm) { "전동킥보드로 약 \(one($0))km 갈 수 있는 양이에요" }

        // Externalities
        let grams = kWh * Energy.gramsCO2PerKWh
        ratio(grams, low: 1, high: 1_000_000) { "탄소로 환산하면 약 \(whole($0))g CO₂ 정도예요" }
        ratio(grams / Energy.treeCO2GramsPerHour, low: 1) {
            $0 >= 24
                ? "나무 한 그루가 약 \(one($0 / 24))일 동안 흡수하는 탄소량이에요"
                : "나무 한 그루가 약 \(whole($0))시간 동안 흡수하는 탄소량이에요"
        }
        ratio(kWh * Energy.krwPerKWh, low: 1, high: 1_000_000) { "전기요금으로 치면 약 \(whole($0))원어치예요" }

        return b.facts
    }

    // MARK: - Keyboard

    static func fingerTravelMeters(keystrokes: Int) -> Double {
        Double(keystrokes) * mmPerKeystroke / 1000
    }

    static func keyboardFacts(characterKeys: Int, totalKeys: Int) -> [FunFact] {
        var facts: [FunFact] = []

        let travel = fingerTravelMeters(keystrokes: totalKeys)
        if totalKeys > 0, travel >= 1 {
            var b = Builder(topic: .typing, subject: "오늘 키를 누르며 손가락이 움직인 거리는")
            b.add(when: true, "약 \(meters(travel))예요")
            b.add(when: travel / Distance.basketballCourt >= 0.5,
                  "농구 코트 약 \(one(travel / Distance.basketballCourt))개 길이예요")
            b.add(when: travel / Distance.soccerField >= 0.3,
                  "축구장 약 \(one(travel / Distance.soccerField))개 길이에 해당해요")
            b.add(when: travel / Distance.bowlingLane >= 1,
                  "볼링 레인 약 \(whole(travel / Distance.bowlingLane))개 길이예요")
            facts += b.facts
        }

        guard characterKeys > 0 else { return facts }
        var t = Builder(topic: .text, subject: "오늘 입력한 문자 \(Formatters.groupedNumber(characterKeys))자는")
        t.add(when: Double(characterKeys) / Text.a4CharsPerPage >= 0.2,
              "A4 용지 약 \(one(Double(characterKeys) / Text.a4CharsPerPage))장 분량이에요")
        t.add(when: Double(characterKeys) / Text.manuscriptSheet >= 1,
              "원고지 약 \(count(Double(characterKeys) / Text.manuscriptSheet))매 분량이에요")
        t.add(when: Double(characterKeys) / Text.kakaoMessage >= 5,
              "메신저 메시지 약 \(count(Double(characterKeys) / Text.kakaoMessage))개를 보낼 수 있는 양이에요")
        t.add(when: Double(characterKeys) / Text.tweet >= 3,
              "트윗 약 \(count(Double(characterKeys) / Text.tweet))개 분량이에요")
        t.add(when: Double(characterKeys) / Text.shortNovel * 100 >= 1,
              "단편 소설 한 편의 약 \(whole(Double(characterKeys) / Text.shortNovel * 100))%에 해당해요")
        return facts + t.facts
    }

    // MARK: - Cursor

    static func cursorFacts(meters value: Double) -> [FunFact] {
        guard value >= 1 else { return [] }
        var b = Builder(topic: .cursor, subject: "오늘 커서가 움직인 거리는")

        b.add(when: true, "약 \(meters(value))예요")
        b.add(when: value / Distance.bowlingLane >= 1,
              "볼링 레인 약 \(whole(value / Distance.bowlingLane))개 길이예요")
        b.add(when: value / Distance.poolLength >= 1,
              "수영장을 약 \(one(value / Distance.poolLength / 2))번 왕복한 거리예요")
        b.add(when: value / Distance.soccerField >= 0.5,
              "축구장 약 \(one(value / Distance.soccerField))개 길이에 해당해요")
        b.add(when: value / Distance.boeing747 >= 0.5,
              "보잉 747 약 \(one(value / Distance.boeing747))대를 늘어놓은 길이예요")
        b.add(when: value / Distance.trackLoop >= 0.3,
              "운동장 트랙 약 \(one(value / Distance.trackLoop))바퀴예요")
        b.add(when: value / Distance.marathon * 100 >= 0.5,
              "마라톤 풀코스의 약 \(one(value / Distance.marathon * 100))%예요")
        b.add(when: value / Distance.seoulToBusan * 100 >= 0.1,
              String(format: "서울에서 부산까지 거리의 약 %.2f%%예요", value / Distance.seoulToBusan * 100))
        b.add(when: value / Distance.earthCircumference * 100 >= 0.001,
              String(format: "지구 둘레의 약 %.4f%%예요", value / Distance.earthCircumference * 100))
        return b.facts
    }

    // MARK: - Scroll

    static func scrollFacts(screens: Double, screenHeightMeters: Double) -> [FunFact] {
        guard screens >= 0.5 else { return [] }
        let h = screens * screenHeightMeters
        var b = Builder(topic: .scroll, subject: "오늘 스크롤한 화면 약 \(count(screens))개 높이는")

        b.add(when: h / Height.stairStep >= 20, "계단 약 \(count(h / Height.stairStep))칸을 오른 높이예요")
        b.add(when: h / Height.buildingFloor >= 1, "건물 약 \(whole(h / Height.buildingFloor))층 높이에 해당해요")
        b.add(when: h / Height.namsanTower * 100 >= 5, "남산타워 높이의 약 \(whole(h / Height.namsanTower * 100))%예요")
        b.add(when: h / Height.building63 * 100 >= 5, "63빌딩 높이의 약 \(whole(h / Height.building63 * 100))%예요")
        b.add(when: h / Height.eiffelTower * 100 >= 5, "에펠탑 높이의 약 \(whole(h / Height.eiffelTower * 100))%예요")
        b.add(when: h / Height.lotteWorldTower * 100 >= 5, "롯데월드타워 높이의 약 \(whole(h / Height.lotteWorldTower * 100))%예요")
        b.add(when: h / Height.hallasan * 100 >= 2, "한라산 높이의 약 \(whole(h / Height.hallasan * 100))%예요")
        b.add(when: h / Height.baekdusan * 100 >= 2, "백두산 높이의 약 \(whole(h / Height.baekdusan * 100))%예요")
        b.add(when: h / Height.everest * 100 >= 1, "에베레스트 높이의 약 \(one(h / Height.everest * 100))%예요")
        return b.facts
    }

    // MARK: - Time

    static func timeFacts(activeSeconds: Int, focusSeconds: Int, screenOnSeconds: Int) -> [FunFact] {
        guard activeSeconds > 60 else { return [] }
        let minutes = Double(activeSeconds) / 60
        var b = Builder(topic: .time, subject: "오늘 Mac을 실제로 쓴 시간은")

        b.add(when: true, "\(Formatters.compactDuration(activeSeconds))이에요")
        b.add(when: minutes / Time.movieMinutes >= 0.2,
              "영화 약 \(one(minutes / Time.movieMinutes))편을 볼 수 있는 시간이에요")
        b.add(when: minutes / Time.sitcomMinutes >= 1,
              "시트콤 약 \(whole(minutes / Time.sitcomMinutes))편 분량이에요")
        b.add(when: minutes / Time.songMinutes >= 5,
              "노래 약 \(whole(minutes / Time.songMinutes))곡을 들을 수 있는 시간이에요")
        b.add(when: minutes / Time.ramenMinutes >= 5,
              "라면을 약 \(whole(minutes / Time.ramenMinutes))번 끓일 수 있는 시간이에요")
        b.add(when: minutes / (24 * 60) * 100 >= 5,
              "하루 24시간의 약 \(whole(minutes / (24 * 60) * 100))%예요")

        var facts = b.facts
        let pomodoros = Double(focusSeconds) / 60 / Time.pomodoroMinutes
        if pomodoros >= 1 {
            facts.append(FunFact(topic: .focus,
                                 text: "오늘 집중한 시간은 포모도로 약 \(one(pomodoros))세트에 해당해요"))
        }
        if screenOnSeconds > activeSeconds, screenOnSeconds > 600 {
            let idle = screenOnSeconds - activeSeconds
            facts.append(FunFact(topic: .screen,
                                 text: "오늘 화면이 켜져 있던 시간 중 \(Formatters.compactDuration(idle))은 자리를 비운 시간이에요"))
        }
        return facts
    }

    // MARK: - Network

    static func networkFacts(downloadBytes: UInt64, uploadBytes: UInt64, peakDownPerSec: Double) -> [FunFact] {
        let total = Double(downloadBytes) + Double(uploadBytes)
        guard total > 1024 * 1024 else { return [] }
        var b = Builder(topic: .network, subject: "오늘 주고받은 인터넷 데이터는")

        b.add(when: true, "\(Formatters.bytes(UInt64(total)))예요")
        b.add(when: Double(downloadBytes) / Payload.streamingPerHour1080p >= 0.1,
              "1080p 영상 약 \(one(Double(downloadBytes) / Payload.streamingPerHour1080p))시간 분량이에요")
        b.add(when: Double(downloadBytes) / Payload.streamingPerHour4K >= 0.1,
              "4K 영상 약 \(one(Double(downloadBytes) / Payload.streamingPerHour4K))시간 분량이에요")
        b.add(when: total / Payload.song >= 5, "MP3 약 \(count(total / Payload.song))곡에 해당해요")
        b.add(when: total / Payload.photo >= 5, "사진 약 \(count(total / Payload.photo))장 분량이에요")
        b.add(when: total / Payload.email >= 50, "이메일 약 \(count(total / Payload.email))통에 해당해요")
        b.add(when: total / Payload.floppy >= 20, "옛날 플로피 디스크 약 \(count(total / Payload.floppy))장이 필요한 양이에요")
        b.add(when: total / Payload.cd >= 0.3, "CD 약 \(one(total / Payload.cd))장 분량이에요")
        b.add(when: total / Payload.dvd >= 0.2, "DVD 약 \(one(total / Payload.dvd))장 분량이에요")

        var facts = b.facts
        if peakDownPerSec > 100 * 1024 {
            facts.append(FunFact(topic: .network,
                                 text: "오늘 가장 빨랐던 다운로드 속도는 약 \(Formatters.bytesPerSecond(peakDownPerSec))였어요"))
        }
        return facts
    }

    // MARK: - Pointer behaviour

    static func clickFacts(totalClicks: Int, scrollDirectionChanges: Int, activeSeconds: Int) -> [FunFact] {
        var facts: [FunFact] = []
        if totalClicks >= 50 {
            facts.append(FunFact(topic: .pointer,
                                 text: "오늘 클릭한 횟수는 \(Formatters.groupedNumber(totalClicks))번이에요"))
            if activeSeconds > 600 {
                let perMinute = Double(totalClicks) / (Double(activeSeconds) / 60)
                facts.append(FunFact(topic: .pointer,
                                     text: "오늘 클릭은 사용 중 1분에 약 \(one(perMinute))번 꼴이었어요"))
            }
        }
        if scrollDirectionChanges >= 30 {
            facts.append(FunFact(topic: .pointer,
                                 text: "오늘 스크롤 방향을 \(Formatters.groupedNumber(scrollDirectionChanges))번 바꿨어요. 뭔가 찾고 있었나 봐요"))
        }
        return facts
    }
}
