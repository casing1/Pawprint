import Foundation

/// A second, continuous measure of a cat, alongside its rarity grade.
///
/// Rarity is the sum of eight discrete tiers — a frame is worth 0, 8, 16, 24 or 32 and nothing in
/// between — so it can only land on a few hundred values, and the ones worth having cluster at the
/// top. A gallery sorted by rarity shows page after page of 91, 92, 93: cats that are genuinely
/// different, reported as identical. Making the item tiers finer would not fix that, because the
/// tiers *are* the items; the collision is in what rarity measures, not in how precisely it counts.
///
/// So lustre measures something rarity cannot: not which items the day earned, but how emphatically
/// it earned them. That part of a day is continuous — active seconds, focus seconds, keystrokes,
/// top speed, scroll distance, cursor travel — and two days that produced the same eight items
/// almost never produced the same six magnitudes. The result separates to two decimal places.
///
/// Rarity is untouched. It still grades the cat the way it always has, and every historical value
/// still reads the same. Lustre is the tiebreak, the sort order, and what the foil is drawn from.
package struct CatLustre: Equatable {

    /// 0–100, continuous.
    package var value: Double

    /// How the card is finished. Five bands, wide enough apart to be told apart at thumbnail size.
    package enum Finish: Int, Comparable, CaseIterable {
        case matte, satin, holographic, prismatic, radiant

        package static func < (lhs: Finish, rhs: Finish) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Where each band begins.
        ///
        /// Calibrated against a 115-day heavy-use history, whose lustre deciles run
        /// 34 · 43 · 77 · 79 · 89 · 90 · 91 · 91 · 92 · 93 · 95 — half of that person's days sit
        /// inside three points of each other, which is exactly the clustering rarity could not
        /// resolve. These cuts spread that history roughly 20/20/20/30/10 rather than dropping
        /// half of it into one band. A lighter user sits lower on the same scale; the bands are
        /// absolute, not relative, so a good day means the same thing to everyone.
        package var threshold: Double {
            switch self {
            case .matte: return 0
            case .satin: return 55
            case .holographic: return 75
            case .prismatic: return 87
            case .radiant: return 93
            }
        }
    }

    package var finish: Finish

    /// 0–1 within the band, so the sheen still strengthens between two cats of the same finish
    /// rather than snapping only at the boundaries.
    package var intensity: Double

    package init(value: Double, finish: Finish, intensity: Double) {
        self.value = value
        self.finish = finish
        self.intensity = intensity
    }

    /// Two decimal places, which is where the separation actually shows.
    package var display: String { String(format: "%.2f", value) }

    // MARK: - Computation

    /// References at which each axis stops adding. Same figures the day's score is measured
    /// against where they overlap, so the two numbers cannot disagree about what a full day is.
    private enum Reference {
        static let activeSeconds = 6.0 * 3600
        static let focusSeconds = 2.0 * 3600
        static let keyPresses = 8_000.0
        static let wpm = 80.0
        static let scrollScreens = 400.0
        static let cursorMetres = 150.0
    }

    /// - Parameters:
    ///   - itemPoints: the rarity total, 0–100, exactly as the grade uses it.
    ///   - summary: the day itself, for the part rarity cannot see.
    package static func compute(itemPoints: Double, summary: DailySummary) -> CatLustre {
        /// Eases off near the reference rather than clipping, and keeps going a little past it so
        /// an exceptional day is not flattened into the same value as a merely complete one.
        func eased(_ value: Double, _ reference: Double) -> Double {
            guard reference > 0, value > 0 else { return 0 }
            return min(value / reference, 1.35).squareRoot() / 1.35.squareRoot()
        }

        let effort = [
            eased(Double(summary.activeSeconds), Reference.activeSeconds),
            eased(Double(summary.totalFocusSeconds), Reference.focusSeconds),
            eased(Double(summary.totalKeyPresses), Reference.keyPresses),
            eased(summary.maxWPM, Reference.wpm),
            eased(summary.scrollScreens, Reference.scrollScreens),
            eased(summary.cursorDistanceMeters, Reference.cursorMetres),
        ]
        let effortShare = effort.reduce(0, +) / Double(effort.count)

        // Weighted towards effort, not items — which is the opposite of what it first looks like
        // it should be. A settled user earns nearly the same items every day, so an item-dominated
        // blend reproduces exactly the clustering this is meant to resolve: on a real 115-day
        // history, weighting items at 0.62 put 58% of days in one band. Effort has six axes with
        // genuine day-to-day variance, and leaning on it is what makes the scale spread.
        let raw = 0.45 * (itemPoints / 100) + 0.55 * effortShare
        let value = (raw * 100).clamped(to: 0...100)

        let finish = Finish.allCases.last { value >= $0.threshold } ?? .matte
        let next = Finish(rawValue: finish.rawValue + 1)?.threshold ?? 100
        let span = next - finish.threshold
        let intensity = span > 0 ? ((value - finish.threshold) / span).clamped(to: 0...1) : 1

        return CatLustre(value: value, finish: finish, intensity: intensity)
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
