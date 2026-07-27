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
        /// Stable across rebuilds. `groups` is a computed property, so a `UUID()` here would be
        /// freshly minted on every render — ForEach identity would churn, and hover state (which
        /// remembers an id across renders) could never match anything.
        var id: String { group + "/" + name }
        let group: String
        let name: String
        /// What has to happen for this to appear.
        let condition: String
        /// Rarity points, or nil on axes that don't score.
        let points: Int?
        /// A cat wearing this item and nothing else, so the row can show what it looks like.
        /// Nil on the date-seeded axes, which show `swatches` instead — a single cat can't convey
        /// "fourteen coat colours", which is the only thing those rows have to say.
        let preview: PawpetTraits?
        /// Colours to lay out as a strip, for rows describing a whole range.
        var swatches: [Color] = []
        /// Miniature cats differing only in the axis this row describes. Used where the variation
        /// is a shape rather than a colour, and a swatch would have nothing to show.
        var strip: [PawpetTraits] = []
    }

    /// The cat every preview starts from — deliberately not left to the date seed.
    ///
    /// The coat is pinned to the warm plain one because a dark palette swallows exactly the items
    /// worth looking at: a collar, a cheek mark and a charm all read as a few dim pixels against
    /// charcoal fur. Fixing it also keeps every row on the same animal, so the only thing that
    /// changes down the list is the item being described.
    ///
    /// The expression is forced to `.content` because an empty day otherwise resolves to `.sleepy`
    /// (under five minutes of activity), which would put half-shut eyes on every thumbnail.
    static var baseCat: PawpetTraits {
        var traits = PawpetTraits(day: previewDay, summary: DailySummary(day: previewDay))
        traits.paletteIndex = 0
        traits.eyeColorIndex = 1
        traits.pattern = .plain
        traits.ears = .pointed
        traits.tail = .curved
        traits.cheekFluff = .light
        traits.whiskers = 3
        traits.expression = .content
        return traits
    }

    private static let previewDay = "2025-03-14"

    private static func preview(_ configure: (inout PawpetTraits) -> Void) -> PawpetTraits {
        var traits = baseCat
        configure(&traits)
        return traits
    }

    struct Group: Identifiable {
        var id: String { title }
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
            Item(group: "frame", name: PawpetTraits.frameName(frame), condition: condition,
                 points: Int(PawpetTraits.framePoints(frame)),
                 preview: preview { $0.frame = frame })
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
            items: PawpetTraits.PawCharm.allCases.filter { $0 != .none }.map { charm in
                Item(group: "charm", name: PawpetTraits.pawCharmName(charm), condition: condition, points: 20,
                     preview: preview { $0.pawCharm = charm })
            },
            isEarned: true)
    }

    private static var wings: Group {
        let condition = L10n.t("itemCatalog.wings.condition", 400, 700)
        return Group(
            title: L10n.t("itemCatalog.wings"), icon: "wind",
            summary: L10n.t("itemCatalog.wings.summary"), maximum: 16,
            items: PawpetTraits.Wings.allCases.filter { $0 != .none }.map { wings in
                Item(group: "wings", name: PawpetTraits.wingsName(wings), condition: condition, points: 16,
                     preview: preview { $0.wings = wings })
            },
            isEarned: true)
    }

    private static var backdrops: Group {
        func item(_ backdrop: PawpetTraits.Backdrop, _ condition: String) -> Item {
            Item(group: "backdrop", name: PawpetTraits.backdropName(backdrop), condition: condition,
                 points: Int(PawpetTraits.backdropPoints(backdrop)),
                 preview: preview { $0.backdrop = backdrop })
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
            Item(group: "collar", name: PawpetTraits.collarName(collar), condition: condition,
                 points: Int(PawpetTraits.collarPoints(collar)),
                 preview: preview { $0.collar = collar })
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
            Item(group: "headwear", name: PawpetTraits.headwearName(headwear), condition: condition,
                 points: Int(PawpetTraits.headwearPoints(headwear)),
                 preview: preview { $0.headwear = headwear })
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
            Item(group: "expression", name: PawpetTraits.expressionName(expression), condition: condition,
                 points: Int(PawpetTraits.expressionPoints(expression)),
                 preview: preview { $0.expression = expression })
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
            Item(group: "floaters", name: PawpetTraits.floatersName(floaters), condition: condition, points: 2,
                 preview: preview { $0.floaters = floaters })
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
                Item(group: "eyewear", name: PawpetTraits.eyewearName(.sunglasses),
                     condition: L10n.t("itemCatalog.eye.sunglasses", 8), points: nil,
                     preview: preview { $0.eyewear = .sunglasses }),
                Item(group: "eyewear", name: PawpetTraits.eyewearName(.readingGlasses),
                     condition: L10n.t("itemCatalog.eye.reading", Formatters.groupedNumber(8_000)),
                     points: nil,
                     preview: preview { $0.eyewear = .readingGlasses })
            ],
            isEarned: false)
    }

    private static var props: Group {
        func item(_ prop: PawpetTraits.Prop, _ condition: String) -> Item {
            Item(group: "prop", name: PawpetTraits.propName(prop), condition: condition, points: nil,
                 preview: preview { $0.prop = prop })
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
            Item(group: "cheek", name: PawpetTraits.cheekMarkName(cheek), condition: condition, points: nil,
                 preview: preview { $0.cheekMark = cheek })
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
            items: [(PawpetTraits.Aura.dawn, 5, 8), (.morning, 8, 12), (.afternoon, 12, 17),
                    (.evening, 17, 21), (.night, 21, 24), (.deepNight, 0, 5)].map { aura, from, to in
                Item(group: "aura", name: PawpetTraits.auraName(aura),
                     condition: L10n.t("itemCatalog.aura.condition", from, to), points: nil,
                     preview: preview { $0.aura = aura })
            },
            isEarned: false)
    }

    /// The date-seeded axes.
    ///
    /// These describe *ranges*, not items, so they're the one place a preview cat is the wrong
    /// picture: showing one cat for "coat colours" told you nothing about the other thirteen, and
    /// nothing at all about which part of the cat the row even meant. The colour axes show their
    /// full palette as a strip; the shape axes, which have no colour to show, state their count.
    private static var coat: Group {
        func swatchItem(_ nameKey: String, _ colors: [Color]) -> Item {
            Item(group: "coat", name: L10n.t(nameKey),
                 condition: L10n.t("itemCatalog.coat.count", colors.count), points: nil,
                 preview: nil, swatches: colors)
        }
        func stripItem(_ nameKey: String, _ variants: [PawpetTraits]) -> Item {
            Item(group: "coat", name: L10n.t(nameKey),
                 condition: L10n.t("itemCatalog.coat.count", variants.count), points: nil,
                 preview: nil, strip: variants)
        }
        return Group(
            title: L10n.t("itemCatalog.coat"), icon: "paintpalette",
            summary: L10n.t("itemCatalog.coat.summary"), maximum: nil,
            items: [
                swatchItem("itemCatalog.coat.colours", PawpetTraits.palettes.map(\.body)),
                swatchItem("itemCatalog.coat.eyes", PawpetTraits.eyeColors.map(\.color)),
                stripItem("itemCatalog.coat.patterns",
                          PawpetTraits.Pattern.allCases.map { p in preview { $0.pattern = p } }),
                stripItem("itemCatalog.coat.ears",
                          PawpetTraits.EarShape.allCases.map { e in preview { $0.ears = e } }),
                stripItem("itemCatalog.coat.tails",
                          PawpetTraits.TailShape.allCases.map { t in preview { $0.tail = t } })
            ],
            isEarned: false)
    }
}

/// Browsable list of every item, grouped by axis.
@MainActor
struct PawpetItemCatalogView: View {
    var onClose: () -> Void

    /// Which row's preview is magnified. One at a time, so running down the list doesn't leave a
    /// trail of enlarged cats behind.
    @State private var hovered: String?

    /// Forces one row into its magnified state. Verification only: `ImageRenderer` has no pointer,
    /// and posting a synthetic mouse-moved event needs an Accessibility grant.
    var forcedHover: String?

    /// Previews are driven entirely by `traitsOverride`; this only satisfies the initialiser.
    private let emptyDay = DailySummary(day: "2025-03-14")

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

    /// One item: what it looks like, what it's called, when it shows up, what it's worth.
    ///
    /// The thumbnail is a real cat wearing only this item, drawn by the same renderer as the
    /// gallery — not a separate icon set that could quietly stop matching.
    ///
    /// At 46pt a collar or a cheek mark is only a few pixels, so hovering enlarges it.
    ///
    /// The enlargement draws a *second* cat at its full size rather than applying `scaleEffect`
    /// to the small one. `PawpetView` is a `Canvas`, so scaling it up magnifies the 46pt raster
    /// — the result was visibly soft exactly when you were trying to look closely. Drawing at
    /// 100pt re-runs the vector path at that size and stays sharp.
    ///
    /// Deliberately not a `.popover`: a popover is a real window, and one per row means the list
    /// spawns and tears down windows every time the pointer crosses it.
    @ViewBuilder
    private func row(_ item: PawpetItemCatalog.Item) -> some View {
        let isHovered = (forcedHover ?? hovered) == item.id
        HStack(alignment: .center, spacing: 9) {
            if let preview = item.preview {
                PawpetView(summary: emptyDay, size: 46, showsAura: true, traitsOverride: preview)
                    .opacity(isHovered ? 0 : 1)
                    .overlay(alignment: .leading) {
                        if isHovered {
                            PawpetView(summary: emptyDay, size: 100, showsAura: true,
                                       traitsOverride: preview)
                                .padding(5)
                                // Opaque: it covers the row's own text, which would otherwise
                                // show through the cat.
                                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(.background))
                                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
                                .offset(x: -5)
                        }
                    }
                    .frame(width: 46, height: 46)
                    // Above its own row's text as well as the neighbouring rows: siblings in an
                    // HStack draw in order, so the label would otherwise sit on top of the cat.
                    .zIndex(isHovered ? 1 : 0)
                    .onHover { hovered = $0 ? item.id : (isHovered ? nil : hovered) }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 11, weight: .medium))
                Text(item.condition)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.swatches.isEmpty { swatchStrip(item.swatches) }
                if !item.strip.isEmpty { catStrip(item.strip) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let points = item.points {
                Text("+\(points)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(points > 0 ? Color.accentColor : Color.secondary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
        // Without this the magnified cat is painted under the rows that follow it.
        .zIndex(isHovered ? 1 : 0)
    }

    /// The whole palette for an axis whose only content is "there are N of these".
    private func swatchStrip(_ colors: [Color]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 15, height: 15)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 1)
    }

    /// Every variant of a shape axis, side by side. Small, but side-by-side is the only way a
    /// difference in ear or tail shape is legible at all.
    private func catStrip(_ variants: [PawpetTraits]) -> some View {
        HStack(spacing: 1) {
            ForEach(Array(variants.enumerated()), id: \.offset) { _, traits in
                PawpetView(summary: emptyDay, size: 42, showsAura: false, traitsOverride: traits)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    func groupCard(_ group: PawpetItemCatalog.Group) -> some View {
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
                    row(item)
                }
            }
            .padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045)))
        }
    }
}
