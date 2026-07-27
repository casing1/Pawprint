import SwiftUI

/// Every item a cat can wear, what unlocks it, and what it is worth.
///
/// The rules already existed in `PawpetTraits`, but only as code paths — there was no way to learn
/// that a paw charm needs 4,000 keys, or that a gold frame is worth 24 of the 100 rarity points.
/// This is the readable side of the same rules.
///
/// Names and point values are read from `PawpetTraits` rather than retyped, so they cannot drift
/// from what the cat actually shows or scores. The unlock conditions are prose and are the one
/// part kept in step by hand — each mirrors a threshold in the corresponding `PawpetTraits`
/// resolver, and every number appearing here is substituted in rather than written into the
/// translation, so a changed threshold is a one-line change in one place.
enum PawpetItemCatalog {

    struct Item: Identifiable {
        let id = UUID()
        let name: String
        /// What has to happen for this to appear.
        let condition: String
        /// Rarity points, or nil on axes that don't score.
        let points: Int?
    }

    struct Group: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        /// How the axis works, and — where it scores — what it is worth.
        let summary: String
        /// Points available on this axis, nil when it doesn't score.
        let maximum: Int?
        let items: [Item]
        /// Earned axes are listed first and marked; the rest merely describe the day.
        let isEarned: Bool
    }

    static var groups: [Group] {
        [frames, charms, wings, backdrops, collars, headwear, expressions, floaters,
         eyewear, props, cheeks, auras, coat]
    }

    /// Rarity points the scoring axes can award between them. Derived, so it tracks the table.
    static var totalPoints: Int { groups.compactMap(\.maximum).reduce(0, +) }

    // MARK: - Scoring axes

    private static var frames: Group {
        func item(_ frame: PawpetTraits.Frame, _ condition: String) -> Item {
            Item(name: PawpetTraits.frameName(frame), condition: condition,
                 points: Int(PawpetTraits.framePoints(frame)))
        }
        return Group(
            title: L10n.t("itemCatalog.frames"), icon: "square.dashed",
            summary: L10n.t("itemCatalog.frames.summary"), maximum: 32,
            items: [
                item(.prismatic, L10n.t("itemCatalog.frame.prismatic", 85)),
                item(.gold, L10n.t("itemCatalog.frame.range", 70, 84)),
                item(.silver, L10n.t("itemCatalog.frame.range", 50, 69)),
                item(.bronze, L10n.t("itemCatalog.frame.range", 30, 49))
            ],
            isEarned: true)
    }

    private static var charms: Group {
        let condition = L10n.t("itemCatalog.charm.condition", Formatters.groupedNumber(4_000))
        return Group(
            title: L10n.t("itemCatalog.charms"), icon: "sparkles",
            summary: L10n.t("itemCatalog.charms.summary"), maximum: 20,
            items: PawpetTraits.PawCharm.allCases.filter { $0 != .none }.map {
                Item(name: PawpetTraits.pawCharmName($0), condition: condition, points: 20)
            },
            isEarned: true)
    }

    private static var wings: Group {
        let condition = L10n.t("itemCatalog.wings.condition", 400, 700)
        return Group(
            title: L10n.t("itemCatalog.wings"), icon: "wind",
            summary: L10n.t("itemCatalog.wings.summary"), maximum: 16,
            items: PawpetTraits.Wings.allCases.filter { $0 != .none }.map {
                Item(name: PawpetTraits.wingsName($0), condition: condition, points: 16)
            },
            isEarned: true)
    }

    private static var backdrops: Group {
        func item(_ backdrop: PawpetTraits.Backdrop, _ condition: String) -> Item {
            Item(name: PawpetTraits.backdropName(backdrop), condition: condition,
                 points: Int(PawpetTraits.backdropPoints(backdrop)))
        }
        return Group(
            title: L10n.t("itemCatalog.backdrops"), icon: "rays",
            summary: L10n.t("itemCatalog.backdrops.summary"), maximum: 12,
            items: [
                item(.rays, L10n.t("itemCatalog.backdrop.rays", 80)),
                item(.constellation, L10n.t("itemCatalog.backdrop.constellation", 5)),
                item(.orbit, L10n.t("itemCatalog.backdrop.orbit", 150))
            ],
            isEarned: true)
    }

    private static var collars: Group {
        func item(_ collar: PawpetTraits.Collar, _ condition: String) -> Item {
            Item(name: PawpetTraits.collarName(collar), condition: condition,
                 points: Int(PawpetTraits.collarPoints(collar)))
        }
        return Group(
            title: L10n.t("itemCatalog.collars"), icon: "circle.hexagongrid",
            summary: L10n.t("itemCatalog.collars.summary"), maximum: 8,
            items: [
                item(.rainbow, L10n.t("itemCatalog.collar.atLeast", 30)),
                item(.gold, L10n.t("itemCatalog.collar.range", 14, 29)),
                item(.green, L10n.t("itemCatalog.collar.range", 7, 13)),
                item(.blue, L10n.t("itemCatalog.collar.range", 3, 6)),
                item(.cloth, L10n.t("itemCatalog.collar.range", 1, 2))
            ],
            isEarned: true)
    }

    private static var headwear: Group {
        func item(_ headwear: PawpetTraits.Headwear, _ condition: String) -> Item {
            Item(name: PawpetTraits.headwearName(headwear), condition: condition,
                 points: Int(PawpetTraits.headwearPoints(headwear)))
        }
        return Group(
            title: L10n.t("itemCatalog.headwear"), icon: "crown",
            summary: L10n.t("itemCatalog.headwear.summary"), maximum: 6,
            items: [
                item(.partyHat, L10n.t("itemCatalog.head.partyHat")),
                item(.crown, L10n.t("itemCatalog.head.crown", 85)),
                item(.halo, L10n.t("itemCatalog.head.halo", Formatters.groupedNumber(500), 15)),
                item(.headphones, L10n.t("itemCatalog.head.headphones", 2)),
                item(.nightcap, L10n.t("itemCatalog.head.nightcap", 5)),
                item(.beanie, L10n.t("itemCatalog.head.beanie", 3)),
                item(.bandana, L10n.t("itemCatalog.head.bandana", 10))
            ],
            isEarned: false)
    }

    private static var expressions: Group {
        func item(_ expression: PawpetTraits.Expression, _ condition: String) -> Item {
            Item(name: PawpetTraits.expressionName(expression), condition: condition,
                 points: Int(PawpetTraits.expressionPoints(expression)))
        }
        return Group(
            title: L10n.t("itemCatalog.expressions"), icon: "face.smiling",
            summary: L10n.t("itemCatalog.expressions.summary"), maximum: 4,
            items: [
                item(.sparkle, L10n.t("itemCatalog.face.sparkle")),
                item(.determined, L10n.t("itemCatalog.face.determined", 100)),
                item(.dizzy, L10n.t("itemCatalog.face.dizzy", 30)),
                item(.chaotic, L10n.t("itemCatalog.face.chaotic", 70)),
                item(.surprised, L10n.t("itemCatalog.face.surprised", 60)),
                item(.focused, L10n.t("itemCatalog.face.focused", 45)),
                item(.mischief, L10n.t("itemCatalog.face.mischief", 200)),
                item(.tired, L10n.t("itemCatalog.face.tired", 4, 35)),
                item(.zen, L10n.t("itemCatalog.face.zen", 2)),
                item(.wide, L10n.t("itemCatalog.face.wide", 75)),
                item(.sleepy, L10n.t("itemCatalog.face.sleepy", 5)),
                item(.content, L10n.t("itemCatalog.face.content"))
            ],
            isEarned: false)
    }

    private static var floaters: Group {
        func item(_ floaters: PawpetTraits.Floaters, _ condition: String) -> Item {
            Item(name: PawpetTraits.floatersName(floaters), condition: condition, points: 2)
        }
        return Group(
            title: L10n.t("itemCatalog.floaters"), icon: "sparkle",
            summary: L10n.t("itemCatalog.floaters.summary"), maximum: 2,
            items: [
                item(.sparkles, L10n.t("itemCatalog.float.sparkles")),
                item(.zzz, L10n.t("itemCatalog.float.zzz")),
                item(.bits, L10n.t("itemCatalog.float.bits", 5)),
                item(.notes, L10n.t("itemCatalog.float.notes", 3))
            ],
            isEarned: false)
    }

    // MARK: - Descriptive axes (no points)

    private static var eyewear: Group {
        Group(
            title: L10n.t("itemCatalog.eyewear"), icon: "eyeglasses",
            summary: L10n.t("itemCatalog.noPoints"), maximum: nil,
            items: [
                Item(name: PawpetTraits.eyewearName(.sunglasses),
                     condition: L10n.t("itemCatalog.eye.sunglasses", 8), points: nil),
                Item(name: PawpetTraits.eyewearName(.readingGlasses),
                     condition: L10n.t("itemCatalog.eye.reading", Formatters.groupedNumber(8_000)),
                     points: nil)
            ],
            isEarned: false)
    }

    private static var props: Group {
        func item(_ prop: PawpetTraits.Prop, _ condition: String) -> Item {
            Item(name: PawpetTraits.propName(prop), condition: condition, points: nil)
        }
        return Group(
            title: L10n.t("itemCatalog.props"), icon: "shippingbox",
            summary: L10n.t("itemCatalog.props.summary"), maximum: nil,
            items: [
                item(.moon, L10n.t("itemCatalog.prop.moon", 5)),
                item(.coffee, L10n.t("itemCatalog.prop.coffee", 8)),
                item(.book, L10n.t("itemCatalog.prop.book", Formatters.groupedNumber(20_000))),
                item(.mouse, L10n.t("itemCatalog.prop.mouse", Formatters.groupedNumber(2_000))),
                item(.yarn, L10n.t("itemCatalog.prop.yarn", 300)),
                item(.plug, L10n.t("itemCatalog.prop.plug")),
                item(.fish, L10n.t("itemCatalog.prop.fish", 2))
            ],
            isEarned: false)
    }

    private static var cheeks: Group {
        func item(_ cheek: PawpetTraits.CheekMark, _ condition: String) -> Item {
            Item(name: PawpetTraits.cheekMarkName(cheek), condition: condition, points: nil)
        }
        return Group(
            title: L10n.t("itemCatalog.cheeks"), icon: "face.dashed",
            summary: L10n.t("itemCatalog.noPoints"), maximum: nil,
            items: [
                item(.flushed, L10n.t("itemCatalog.cheek.flushed.when")),
                item(.sweat, L10n.t("itemCatalog.cheek.sweat.when", 120)),
                item(.blush, L10n.t("itemCatalog.cheek.blush.when", 60))
            ],
            isEarned: false)
    }

    private static var auras: Group {
        Group(
            title: L10n.t("itemCatalog.auras"), icon: "sun.horizon",
            summary: L10n.t("itemCatalog.auras.summary"), maximum: nil,
            items: [Item(name: L10n.t("itemCatalog.aura.name"),
                         condition: L10n.t("itemCatalog.aura.condition"), points: nil)],
            isEarned: false)
    }

    /// The date-seeded axes, summarised by count rather than listed — they aren't earned, and
    /// fourteen coat colours as fourteen rows would bury the parts you can actually influence.
    private static var coat: Group {
        func item(_ nameKey: String, _ count: Int) -> Item {
            Item(name: L10n.t(nameKey),
                 condition: L10n.t("itemCatalog.coat.count", count), points: nil)
        }
        return Group(
            title: L10n.t("itemCatalog.coat"), icon: "paintpalette",
            summary: L10n.t("itemCatalog.coat.summary"), maximum: nil,
            items: [
                item("itemCatalog.coat.colours", PawpetTraits.palettes.count),
                item("itemCatalog.coat.patterns", PawpetTraits.Pattern.allCases.count),
                item("itemCatalog.coat.eyes", PawpetTraits.eyeColors.count),
                item("itemCatalog.coat.ears", PawpetTraits.EarShape.allCases.count),
                item("itemCatalog.coat.tails", PawpetTraits.TailShape.allCases.count)
            ],
            isEarned: false)
    }
}

/// Browsable list of every item, grouped by axis.
@MainActor
struct PawpetItemCatalogView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("itemCatalog.title")).font(.headline)
                    Text(L10n.t("itemCatalog.subtitle", PawpetItemCatalog.totalPoints))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
            .padding(14)
            Divider()
            ScrollView { content }
        }
        .frame(width: 430, height: 540)
    }

    /// Split out so verification can snapshot it: `ImageRenderer` draws `ScrollView` contents empty.
    var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(PawpetItemCatalog.groups) { group in
                groupCard(group)
            }
            Text(L10n.t("itemCatalog.footnote"))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }

    @ViewBuilder
    private func groupCard(_ group: PawpetItemCatalog.Group) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: group.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(group.isEarned ? Color.accentColor : Color.secondary)
                Text(group.title).font(.system(size: 12, weight: .semibold))
                if group.isEarned {
                    Text(L10n.t("itemCatalog.earnedTag"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                }
                Spacer()
                if let maximum = group.maximum {
                    Text(L10n.t("itemCatalog.upTo", maximum))
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(group.summary)
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().opacity(0.3) }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 92, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.condition)
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let points = item.points {
                            Text("+\(points)")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(points > 0 ? Color.accentColor : Color.secondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045)))
        }
    }
}
