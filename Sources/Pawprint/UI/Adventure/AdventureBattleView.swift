import SwiftUI
import PawprintCore

/// The interactive battle stage.
///
/// The core engine resolves a turn synchronously and immutably. This view reveals that result in
/// phases so a choice feels like an action: the cat moves, enemy HP changes, the announced attack
/// lands, and only then is the next intent exposed.
@MainActor
struct AdventureBattleView: View {
    let partyCandidates: [PawpetAdventureCandidate]
    let onReturnToParty: () -> Void
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var accessibilityFocus: BattleAccessibilityFocus?

    @State private var battle: AdventureBattleState
    @State private var displayedPartyHealth: Int
    @State private var displayedEnemyHealth: Int
    @State private var phase: BattlePresentationPhase = .choosing
    @State private var activeCatID: String?
    @State private var pendingResolution: AdventureTurnResolution?
    @State private var lastResolution: AdventureTurnResolution?
    @State private var enemyIsHit = false
    @State private var partyIsHit = false
    @State private var showEnemyDamage = false
    @State private var showPartyDamage = false
    @State private var showHealing = false
    @State private var presentationTask: Task<Void, Never>?
    @State private var presentationToken = UUID()

    init(
        initialState: AdventureBattleState,
        partyCandidates: [PawpetAdventureCandidate],
        onReturnToParty: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.partyCandidates = partyCandidates
        self.onReturnToParty = onReturnToParty
        self.onRetry = onRetry
        _battle = State(initialValue: initialState)
        _displayedPartyHealth = State(initialValue: initialState.partyHealth)
        _displayedEnemyHealth = State(initialValue: initialState.enemyHealth)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                battleHeader
                Divider()
                healthStrip
                arena
                    .frame(maxHeight: .infinity)
                Divider()
                actionPanel
            }
            .allowsHitTesting(battle.outcome == nil)
            .accessibilityHidden(battle.outcome != nil)

            if let outcome = battle.outcome {
                resultOverlay(outcome)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.94).combined(with: .opacity)
                    )
                    .zIndex(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            accessibilityFocus = .intent
        }
        .onDisappear {
            cancelPresentation()
        }
    }

    // MARK: - Layout

    private var battleHeader: some View {
        HStack(spacing: 12) {
            Button {
                leaveBattle()
            } label: {
                Label(
                    L10n.t("adventure.battle.backToParty"),
                    systemImage: "chevron.backward"
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(phase.isResolving)

            Divider()
                .frame(height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t("adventure.encounter.title"))
                    .font(.headline)
                Text(L10n.t("adventure.battle.enemy.name"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(
                L10n.t("adventure.battle.round", battle.round, battle.maxRounds),
                systemImage: "flag.checkered"
            )
            .font(.callout.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
            )
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
    }

    private var healthStrip: some View {
        HStack(spacing: 24) {
            BattleHealthMeter(
                label: L10n.t(
                    "adventure.battle.partyHealth",
                    displayedPartyHealth,
                    battle.initialPartyHealth
                ),
                value: displayedPartyHealth,
                total: battle.initialPartyHealth,
                color: .green,
                animates: !reduceMotion
            )

            BattleHealthMeter(
                label: L10n.t(
                    "adventure.battle.enemyHealth",
                    L10n.t("adventure.battle.enemy.name"),
                    displayedEnemyHealth,
                    battle.initialEnemyHealth
                ),
                value: displayedEnemyHealth,
                total: battle.initialEnemyHealth,
                color: .orange,
                animates: !reduceMotion
            )
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(Color.secondary.opacity(0.035))
    }

    private var arena: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.09),
                            Color.yellow.opacity(0.10),
                            Color.orange.opacity(0.12),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.green.opacity(0.10))
                        .frame(height: 52)
                        .padding(.horizontal, 18)
                        .offset(y: 17)
                }

            VStack(spacing: 2) {
                intentCard
                    .frame(maxWidth: 560)
                    .zIndex(3)

                HStack(spacing: 12) {
                    partyFormation
                        .frame(minWidth: 280, maxWidth: .infinity)

                    Spacer(minLength: 72)

                    enemyFormation
                        .frame(width: 178)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var partyFormation: some View {
        ZStack {
            if phase.showsGuardianDefense,
               pendingResolution?.actorRole == .guardian {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.blue.opacity(0.66), lineWidth: 4)
                    .shadow(color: Color.blue.opacity(0.38), radius: 10)
                    .padding(2)
                    .transition(.scale.combined(with: .opacity))
            }

            if showHealing {
                HStack(spacing: 36) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color.green)
                            .symbolEffect(.pulse)
                    }
                }
                .offset(y: -54)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(partyCandidates.enumerated()), id: \.element.id) { index, candidate in
                    battleCat(candidate, index: index)
                }
            }
            .offset(x: partyIsHit ? -8 : 0)
            .rotationEffect(.degrees(partyIsHit ? -1.5 : 0))
            .animation(
                reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.38),
                value: partyIsHit
            )

            if showPartyDamage, let pendingResolution {
                Text("-\(pendingResolution.damageReceived)")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.red)
                    .offset(y: -78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showHealing, let pendingResolution, pendingResolution.healing > 0 {
                Text("+\(pendingResolution.healing)")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.green)
                    .offset(x: 54, y: -72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L10n.t(
                "adventure.battle.partyHealth",
                displayedPartyHealth,
                battle.initialPartyHealth
            )
        )
    }

    private func battleCat(
        _ candidate: PawpetAdventureCandidate,
        index: Int
    ) -> some View {
        let isActing = activeCatID == candidate.id && phase == .playerActing
        let actionOffset = catActionOffset(for: candidate.profile.role, isActing: isActing)

        return VStack(spacing: 3) {
            PawpetView(
                summary: candidate.summary,
                size: 78,
                streakDays: candidate.streakDays,
                showsAura: false
            )
            .accessibilityHidden(true)

            Text(Formatters.shortDayLabel(candidate.summary.day))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)

            Text(roleLabel(candidate.profile.role))
                .font(.caption2)
                .foregroundStyle(roleColor(candidate.profile.role))
        }
        .frame(maxWidth: .infinity)
        .offset(actionOffset)
        .scaleEffect(isActing ? 1.10 : 1)
        .zIndex(isActing ? 4 : Double(index))
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55),
            value: isActing
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.t(
                "adventure.cat.accessibility",
                Formatters.dayLabel(candidate.summary.day),
                roleLabel(candidate.profile.role),
                candidate.profile.grade.rawValue
            )
        )
    }

    private var enemyFormation: some View {
        ZStack {
            VStack(spacing: 0) {
                SunlitWispView(
                    isAttacking: phase == .enemyActing,
                    isHit: enemyIsHit
                )
                .frame(height: 148)

                Text(L10n.t("adventure.battle.enemy.name"))
                    .font(.callout.weight(.semibold))
            }

            if showEnemyDamage, let pendingResolution {
                Text("-\(pendingResolution.damageDealt)")
                    .font(.title2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.orange)
                    .offset(y: -76)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if enemyIsHit,
               pendingResolution?.actorRole == .striker {
                VStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.90))
                            .frame(width: 62, height: 4)
                            .rotationEffect(.degrees(-24))
                    }
                }
                .offset(x: -8, y: -14)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.t(
                "adventure.battle.enemy.accessibility",
                L10n.t("adventure.battle.enemy.name"),
                displayedEnemyHealth,
                battle.initialEnemyHealth,
                intentName(battle.currentIntent)
            )
        )
    }

    private var intentCard: some View {
        let intent = battle.currentIntent
        let color = intentColor(intent)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    L10n.t("adventure.battle.intent.label"),
                    systemImage: "eye.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                HStack(spacing: 9) {
                    Image(systemName: intentIcon(intent))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(color.opacity(0.12)))

                    Text(intentName(intent))
                        .font(.headline)
                        .lineLimit(1)
                }
            }

            Divider()
                .frame(height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text(intentDescription(intent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    L10n.t(
                        "adventure.battle.intent.counter",
                        roleLabel(intent.counterRole)
                    ),
                    systemImage: roleIcon(intent.counterRole)
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityFocused($accessibilityFocus, equals: .intent)
    }

    private var actionPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(phaseText)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Label(
                    L10n.t("adventure.battle.keyboardHint"),
                    systemImage: "keyboard"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(Array(partyCandidates.enumerated()), id: \.element.id) { index, candidate in
                    skillButton(candidate, index: index)
                }
            }

            if let lastResolution {
                feedbackLine(lastResolution)
            } else {
                Text(L10n.t("adventure.battle.feedback.firstTurn"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(height: 178)
        .background(.ultraThinMaterial)
    }

    private func skillButton(
        _ candidate: PawpetAdventureCandidate,
        index: Int
    ) -> some View {
        let skill = candidate.profile.role.skill
        let countersIntent = candidate.profile.role == battle.currentIntent.counterRole
        let enabled = phase == .choosing && battle.outcome == nil
        let color = roleColor(candidate.profile.role)
        let isSelectedAction = activeCatID == candidate.id && phase.isResolving

        return Button {
            chooseSkill(for: candidate)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(color))

                    Text(
                        "\(Formatters.shortDayLabel(candidate.summary.day)) · \(skillName(skill))"
                    )
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if countersIntent {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(color)
                            .help(L10n.t("adventure.battle.counterHint"))
                    }
                }

                Text(skillDescription(skill))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelectedAction || countersIntent
                            ? color.opacity(0.12)
                            : Color.secondary.opacity(0.06)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isSelectedAction
                            ? color.opacity(0.92)
                            : countersIntent
                                ? color.opacity(0.64)
                                : Color.secondary.opacity(0.16),
                        lineWidth: isSelectedAction || countersIntent ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled || isSelectedAction ? 1 : 0.55)
        .keyboardShortcut(shortcutKey(index), modifiers: [])
        .accessibilityLabel(
            L10n.t(
                "adventure.battle.skill.accessibility",
                Formatters.dayLabel(candidate.summary.day),
                skillName(skill)
            )
        )
        .accessibilityHint(skillDescription(skill))
    }

    private func feedbackLine(_ resolution: AdventureTurnResolution) -> some View {
        HStack(spacing: 7) {
            if resolution.counteredIntent {
                Label(
                    L10n.t("adventure.battle.feedback.counter"),
                    systemImage: "checkmark.shield.fill"
                )
                .foregroundStyle(Color.green)
            }

            Text(
                L10n.t(
                    "adventure.battle.feedback.summary",
                    resolution.damageDealt,
                    resolution.damageReceived,
                    resolution.healing,
                    resolution.mitigation
                )
            )
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let passive = resolution.passiveTriggers.first {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(passiveLabel(passive.passive))
                    .foregroundStyle(Color.accentColor)
            }

            Spacer(minLength: 0)
        }
        .font(.caption2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultOverlay(_ outcome: AdventureOutcome) -> some View {
        let victory = outcome == .victory

        return ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 13) {
                Image(systemName: victory ? "checkmark.seal.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(victory ? Color.green : Color.orange)

                Text(
                    victory
                        ? L10n.t("adventure.battle.phase.victory")
                        : L10n.t("adventure.battle.phase.defeat")
                )
                .font(.title2.weight(.bold))

                Text(
                    L10n.t(
                        "adventure.result.health",
                        battle.partyHealth,
                        battle.initialPartyHealth,
                        battle.enemyHealth,
                        battle.initialEnemyHealth
                    )
                )
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

                if !victory,
                   battle.partyHealth > 0,
                   battle.enemyHealth > 0,
                   battle.history.count >= battle.maxRounds {
                    Text(L10n.t("adventure.battle.result.turnLimitDefeat"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(
                    L10n.t("adventure.battle.result.nextAreaLocked"),
                    systemImage: "map"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.09))
                )

                HStack(spacing: 10) {
                    Button {
                        leaveBattle()
                    } label: {
                        Text(L10n.t("adventure.battle.result.changeParty"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        retryBattle()
                    } label: {
                        Text(L10n.t("adventure.battle.result.retry"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 420)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThickMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.22))
            )
            .shadow(color: Color.black.opacity(0.20), radius: 24, y: 10)
            .accessibilityElement(children: .contain)
            .accessibilityFocused($accessibilityFocus, equals: .result)
        }
    }

    // MARK: - Turn presentation

    private func chooseSkill(for candidate: PawpetAdventureCandidate) {
        guard phase == .choosing, battle.outcome == nil else { return }

        let turn: AdventureTurnResult
        do {
            turn = try AdventureEngine.performTurn(catID: candidate.id, in: battle)
        } catch {
            return
        }

        cancelPresentation()
        let token = UUID()
        presentationToken = token
        activeCatID = candidate.id
        pendingResolution = turn.resolution
        phase = .playerActing

        let startingPartyHealth = battle.partyHealth
        presentationTask = Task { @MainActor in
            guard await pause(milliseconds: 260, token: token) else { return }

            phase = .enemyReacting
            enemyIsHit = true
            showEnemyDamage = true
            if turn.resolution.healing > 0 {
                showHealing = true
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                    displayedPartyHealth = min(
                        battle.initialPartyHealth,
                        startingPartyHealth + turn.resolution.healing
                    )
                }
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                displayedEnemyHealth = turn.state.enemyHealth
            }

            guard await pause(milliseconds: 360, token: token) else { return }
            enemyIsHit = false
            showEnemyDamage = false
            showHealing = false

            if turn.resolution.enemyHealthRemaining > 0 {
                phase = .enemyActing
                guard await pause(milliseconds: 300, token: token) else { return }

                if turn.resolution.damageReceived > 0 {
                    phase = .partyReacting
                    partyIsHit = true
                    showPartyDamage = true
                }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                    displayedPartyHealth = turn.state.partyHealth
                }

                guard await pause(milliseconds: 330, token: token) else { return }
                partyIsHit = false
                showPartyDamage = false
            } else {
                displayedPartyHealth = turn.state.partyHealth
            }

            guard presentationToken == token, !Task.isCancelled else { return }
            battle = turn.state
            lastResolution = turn.resolution
            pendingResolution = nil
            activeCatID = nil

            if turn.state.outcome != nil {
                phase = .finished
                accessibilityFocus = .result
                presentationTask = nil
                return
            }

            phase = .revealingIntent
            accessibilityFocus = .intent
            guard await pause(milliseconds: 180, token: token) else { return }
            phase = .choosing
            presentationTask = nil
        }
    }

    private func pause(milliseconds: UInt64, token: UUID) async -> Bool {
        let duration = reduceMotion ? min(milliseconds, 60) : milliseconds
        do {
            try await Task.sleep(nanoseconds: duration * 1_000_000)
        } catch {
            return false
        }
        return !Task.isCancelled && presentationToken == token
    }

    private func cancelPresentation() {
        presentationTask?.cancel()
        presentationTask = nil
        presentationToken = UUID()
    }

    private func leaveBattle() {
        cancelPresentation()
        onReturnToParty()
    }

    private func retryBattle() {
        cancelPresentation()
        onRetry()
    }

    // MARK: - Copy and visual policy

    private var phaseText: String {
        switch phase {
        case .choosing:
            return L10n.t("adventure.battle.phase.choose")
        case .playerActing:
            return L10n.t(
                "adventure.battle.phase.playerAction",
                pendingResolution.map { skillName($0.skill) } ?? ""
            )
        case .enemyReacting:
            return L10n.t("adventure.battle.phase.playerAction", L10n.t("adventure.battle.feedback.hit"))
        case .enemyActing, .partyReacting:
            return L10n.t(
                "adventure.battle.phase.enemyAction",
                intentName(pendingResolution?.enemyIntent ?? battle.currentIntent)
            )
        case .revealingIntent:
            return L10n.t("adventure.battle.phase.nextIntent")
        case .finished:
            return battle.outcome == .victory
                ? L10n.t("adventure.battle.phase.victory")
                : L10n.t("adventure.battle.phase.defeat")
        }
    }

    private func catActionOffset(
        for role: AdventureRole,
        isActing: Bool
    ) -> CGSize {
        guard isActing, !reduceMotion else { return .zero }
        switch role {
        case .guardian: return CGSize(width: 20, height: 0)
        case .striker: return CGSize(width: 46, height: -3)
        case .support: return CGSize(width: 12, height: -14)
        }
    }

    private func shortcutKey(_ index: Int) -> KeyEquivalent {
        switch index {
        case 0: return "1"
        case 1: return "2"
        default: return "3"
        }
    }

    private func roleLabel(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return L10n.t("adventure.role.guardian")
        case .striker: return L10n.t("adventure.role.striker")
        case .support: return L10n.t("adventure.role.support")
        }
    }

    private func roleIcon(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return "shield.fill"
        case .striker: return "bolt.fill"
        case .support: return "heart.fill"
        }
    }

    private func roleColor(_ role: AdventureRole) -> Color {
        switch role {
        case .guardian: return .blue
        case .striker: return .orange
        case .support: return .green
        }
    }

    private func skillName(_ skill: AdventureSkill) -> String {
        switch skill {
        case .guardianGuard: return L10n.t("adventure.battle.skill.guardian.name")
        case .strikerPounce: return L10n.t("adventure.battle.skill.striker.name")
        case .supportMend: return L10n.t("adventure.battle.skill.support.name")
        }
    }

    private func skillDescription(_ skill: AdventureSkill) -> String {
        switch skill {
        case .guardianGuard: return L10n.t("adventure.battle.skill.guardian.description")
        case .strikerPounce: return L10n.t("adventure.battle.skill.striker.description")
        case .supportMend: return L10n.t("adventure.battle.skill.support.description")
        }
    }

    private func intentName(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike: return L10n.t("adventure.battle.intent.heavyStrike.name")
        case .guardedStance: return L10n.t("adventure.battle.intent.guardedStance.name")
        case .drainingMist: return L10n.t("adventure.battle.intent.drainingMist.name")
        }
    }

    private func intentDescription(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike:
            return L10n.t("adventure.battle.intent.heavyStrike.description")
        case .guardedStance:
            return L10n.t("adventure.battle.intent.guardedStance.description")
        case .drainingMist:
            return L10n.t("adventure.battle.intent.drainingMist.description")
        }
    }

    private func intentIcon(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike: return "burst.fill"
        case .guardedStance: return "shield.lefthalf.filled"
        case .drainingMist: return "cloud.fog.fill"
        }
    }

    private func intentColor(_ intent: AdventureEnemyIntent) -> Color {
        switch intent {
        case .heavyStrike: return .red
        case .guardedStance: return .blue
        case .drainingMist: return .purple
        }
    }

    private func passiveLabel(_ passive: AdventurePassive) -> String {
        switch passive {
        case .steady: return L10n.t("adventure.passive.steady")
        case .resilient: return L10n.t("adventure.passive.resilient")
        case .focused: return L10n.t("adventure.passive.focused")
        case .opportunist: return L10n.t("adventure.passive.opportunist")
        case .alert: return L10n.t("adventure.passive.alert")
        }
    }
}

private enum BattlePresentationPhase {
    case choosing
    case playerActing
    case enemyReacting
    case enemyActing
    case partyReacting
    case revealingIntent
    case finished

    var isResolving: Bool {
        switch self {
        case .choosing, .finished:
            return false
        default:
            return true
        }
    }

    var showsGuardianDefense: Bool {
        switch self {
        case .playerActing, .enemyReacting, .enemyActing, .partyReacting:
            return true
        case .choosing, .revealingIntent, .finished:
            return false
        }
    }
}

private enum BattleAccessibilityFocus: Hashable {
    case intent
    case result
}

private struct BattleHealthMeter: View {
    let label: String
    let value: Int
    let total: Int
    let color: Color
    let animates: Bool

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, max(0, CGFloat(value) / CGFloat(total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.72), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 9)
            .animation(animates ? .easeOut(duration: 0.24) : nil, value: value)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) / \(total)")
    }
}
