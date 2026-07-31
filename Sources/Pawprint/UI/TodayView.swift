import SwiftUI
import PawprintCore

@MainActor
struct TodayView: View {
    @Environment(ActivityCenter.self) var activityCenter

    /// Where the fun-fact window starts. Randomized per launch and advanced on a timer.
    @State private var factOffset = Int.random(in: 0..<1000)
    /// Rotated slowly — the facts are meant to be read, not to flicker past.
    private let factTimer = Timer.publish(every: 45, on: .main, in: .common).autoconnect()

    /// Not `private`: the breakdown and comparison sections are extensions in their own files.
    var summary: DailySummary { activityCenter.todaySummary }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            // The one place a storage failure becomes visible. Everything below assumes the day is
            // being kept; when it isn't, saying so beats letting the numbers climb convincingly on
            // a screen that is the only copy of them.
            if let failure = StoreHealth.shared.lastFailure {
                StorageWarning(failure: failure)
            }

            if let broken = RecordTracker.shared.pendingCelebration {
                RecordBrokenBanner(standing: broken) { RecordTracker.shared.clearCelebration() }
            }

            if let score = summary.score {
                ScoreCard(score: score, persona: summary.persona)
            }

            ShareButton(
                mode: .today(summary),
                label: L10n.t("todayView.9f2ea5d8"),
                suggestedFileName: "pawprint_\(summary.day).png"
            )

            if !activityCenter.todayPercentiles.isEmpty {
                PercentileCard(
                    rankings: activityCenter.todayPercentiles,
                    headline: activityCenter.headlinePercentile
                )
            }

            cardGrid

            Text(summary.summarySentence)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))

            if !summary.activityTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(summary.activityTags, id: \.self) { tag in
                        Text("\(tag.emoji) \(tag.label)")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }

            ActivityClockView(
                activityPerMinute: summary.activityPerMinute,
                dayStartHour: activityCenter.settings.dayStartHour
            )

            if !comparisons.isEmpty {
                ComparisonCard(comparisons: comparisons)
            }

            recordChaseSection

            MiniTimelineView(activityPerMinute: summary.activityPerMinute)

            if !summary.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("todayView.8a44ca6e")).font(.caption).foregroundStyle(.secondary)
                    ForEach(summary.highlights) { highlight in
                        HighlightRow(highlight: highlight)
                    }
                }
            }

            funFactsSection
                .id(PopoverRootView.funFactsAnchor)

            if !summary.energyFacts.isEmpty {
                EnergyCard(lines: summary.energyFacts.map(\.text), drainedPercent: summary.batteryDrainedPercent)
            }

            indicesRow

            PawpetCard(summary: summary, streakDays: activityCenter.currentStreak)

            KeyboardHeatmapView(summary: summary)

            if !summary.appInputProfiles.isEmpty {
                AppInputCard(profiles: summary.appInputProfiles)
            }

            breakdowns
        }
        .padding(14)
    }

    /// "How close am I to my own record" — surfaced while the day is still in progress, since a
    /// near-miss you can still act on is more interesting than one reported after midnight.
    private var recordChaseSection: some View {
        let standings = RecordTracker.shared.standings.prefix(3)
        return Group {
            if !standings.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) {
                        Label(L10n.t("todayView.8605982f"), systemImage: "flag.checkered")
                            .font(.caption).foregroundStyle(.secondary)
                        InfoBadge(
                            title: L10n.t("todayView.8605982f"),
                            explanation: L10n.t("todayView.9234fafa"),
                            detail: L10n.t("todayView.ba83ad47")
                        )
                        Spacer()
                    }
                    ForEach(Array(standings)) { standing in
                        RecordChaseRow(standing: standing)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
            }
        }
    }

    /// Facts cycle on their own so the card keeps offering something new, plus a shuffle button
    /// for anyone who wants to keep pulling.
    private var funFactsSection: some View {
        Group {
            if !summary.funFacts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(L10n.t("todayView.f04f7e9b")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { factOffset += 1 }
                        } label: {
                            Image(systemName: "shuffle").font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .help(L10n.t("todayView.00005fd3"))
                    }
                    ForEach(pickedFunFacts) { fact in
                        HStack(alignment: .top, spacing: 6) {
                            Text("✨").font(.caption)
                            Text(fact.text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity)
                    }
                    Text(L10n.t("todayView.d066a442"))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.3)))
                .onReceive(factTimer) { _ in
                    withAnimation(.easeInOut(duration: 0.4)) { factOffset += 1 }
                }
            }
        }
    }

    /// Five facts, each about a *different* quantity. The conversion engine deliberately produces
    /// many analogies per quantity, so picking blindly would show five ways of saying the same
    /// thing. Topics are walked in a rotating order and one line is taken from each.
    private var pickedFunFacts: [FunFact] {
        let facts = summary.funFacts
        guard facts.count > 5 else { return facts }

        var byTopic: [FunFact.Topic: [FunFact]] = [:]
        for fact in facts { byTopic[fact.topic, default: []].append(fact) }
        let topics = FunFact.Topic.allCases.filter { byTopic[$0] != nil }
        guard !topics.isEmpty else { return Array(facts.prefix(5)) }

        var picked: [FunFact] = []
        for step in 0..<topics.count where picked.count < 5 {
            let topic = topics[(factOffset + step) % topics.count]
            guard let pool = byTopic[topic], !pool.isEmpty else { continue }
            picked.append(pool[factOffset % pool.count])
        }
        // If there were fewer than five distinct topics, top up with whatever is left.
        if picked.count < 5 {
            for fact in facts where picked.count < 5 && !picked.contains(fact) {
                picked.append(fact)
            }
        }
        return picked
    }

    /// Compares a few headline metrics against the recent average.
    private var header: some View {
        let mood = MascotMood.current(activityCenter: activityCenter)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.dayLabel(summary.day))
                    .font(.headline)
                RecordingStatusLabel()
            }
            Spacer()
            HStack(spacing: 6) {
                if activityCenter.liveWPM >= 1 {
                    Text(String(format: "%.0f WPM", activityCenter.liveWPM))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .transition(.opacity)
                }
                Text(mood.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                MascotView(mood: mood, size: 32)
            }
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(activityCenter.settings.dashboardCardIDs, id: \.self) { id in
                if let metric = MetricCatalog.metric(id: id) {
                    StatCard(metric: metric, summary: summary)
                }
            }
        }
    }

    private var indicesRow: some View {
        HStack(spacing: 8) {
            IndexBadge(
                title: MetricExplanations.regret.title,
                value: summary.regretIndex,
                color: .orange,
                explanation: MetricExplanations.regret.body,
                detail: MetricExplanations.regret.detail
            )
            IndexBadge(
                title: MetricExplanations.chaos.title,
                value: summary.chaosIndex,
                color: .purple,
                explanation: MetricExplanations.chaos.body,
                detail: MetricExplanations.chaos.detail
            )
        }
    }
}

@MainActor
private struct RecordingStatusLabel: View {
    @Environment(ActivityCenter.self) private var activityCenter

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(activityCenter.isRecordingActive ? .green : .secondary)
                .frame(width: 6, height: 6)
            Text(activityCenter.isRecordingActive ? L10n.t("todayView.20f5a114") : (activityCenter.settings.isPaused ? L10n.t("todayView.2c992a87") : L10n.t("todayView.69b3a3dc")))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
private struct HighlightRow: View {
    let highlight: Highlight

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: highlight.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(highlight.title).font(.caption.weight(.semibold))
                Text(highlight.detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
private struct IndexBadge: View {
    let title: String
    let value: Double
    let color: Color
    var explanation: String? = nil
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                if let explanation {
                    InfoBadge(title: title, explanation: explanation, detail: detail)
                }
            }
            HStack {
                ProgressView(value: min(value, 100), total: 100)
                    .tint(color)
                Text("\(Int(value))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }
}

/// Shown at the top of Today when storage has failed.
///
/// Deliberately plain and non-alarming: it says what happened and what would help, and it goes
/// away on its own the moment a write succeeds. It is not a modal and there is nothing to dismiss —
/// a warning the user can silence while the problem continues is worse than none.
struct StorageWarning: View {
    let failure: StoreFailure

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(failure.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}
