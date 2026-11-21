import SwiftData
import SwiftUI

/// One task as a card (DESIGN.md 7.2). Progress is the whole card: the fill
/// grows from the left edge.
///
/// Gestures (DESIGN.md 8.1): tap cycles the quick stat, double tap opens the
/// details, a long press logs one. The Task details screen reuses the card
/// as its tracker (`style: .tracker`), where only the long press applies.
struct TaskCard: View {
    enum Style {
        /// A card in the Track grid.
        case track
        /// The large card at the top of Task details.
        case tracker
    }

    let task: TaskItem
    let rules: TaskRules
    let snapshot: TaskSnapshot
    var style: Style = .track
    var settings: TrackSettings = TrackSettings()
    var onOpen: () -> Void = {}

    @Environment(\.slTheme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.appClock) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppRouter.self) private var router

    /// How far the current hold has advanced toward the next step, 0 to 1.
    @State private var phase = 0.0
    @State private var popCount = 0
    @State private var successCount = 0
    @State private var softCount = 0

    private var count: Int { snapshot.periodCount }

    private var shownStat: QuickStat {
        guard style == .track else { return .progress }
        return CardStatusFormatter.shownStat(task.quickStat, rules: rules, streakEmphasis: settings.streakEmphasis)
    }

    private var status: CardStatus {
        CardStatusFormatter.status(rules: rules, snapshot: snapshot, stat: shownStat)
    }

    /// An "exactly N" task at its target takes no more (DESIGN.md 6.2).
    private var canLog: Bool {
        !(rules.kind == .do && rules.goalMode == .exactly && count >= rules.doTarget)
    }

    /// No travel animation with Reduce Motion or with effects switched off
    /// (DESIGN.md 8.2 and 9.5).
    private var animatesHold: Bool {
        !reduceMotion && settings.effectsEnabled
    }

    /// Done cards dim to about 55%; a clear Avoid card dims slightly.
    private var dimming: Double {
        guard rules.isScored else { return 1 }
        switch rules.kind {
        case .do: return snapshot.isMet ? 0.55 : 1
        case .avoid: return count == 0 ? 0.8 : 1
        }
    }

    var body: some View {
        let metrics = theme.metrics
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 2) {
            Text(task.name)
                .font(theme.font(style == .track ? .cardTitle : .trackerTitle))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(theme.typography.cardTitleMinimumScale)
            Text(CardStatusFormatter.periodName(rules.period))
                .font(theme.font(.secondary))
                .foregroundStyle(palette.textSecondary)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(status.value)
                    .font(theme.font(.status))
                    .foregroundStyle(palette.textPrimary)
                    .contentTransition(.numericText())
                Text(status.caption)
                    .font(theme.font(.secondary))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(metrics.innerPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: style == .track ? metrics.cardHeight : metrics.trackerCardHeight,
            alignment: .topLeading
        )
        .background {
            ZStack(alignment: .bottomTrailing) {
                SLSurface(role: .card)
                fill
                Image(systemName: task.symbol)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(palette.iconGhost)
                    .padding(.trailing, 10)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
            }
        }
        .opacity(dimming)
        .contentShape(shape)
        .keyframeAnimator(initialValue: 1.0, trigger: popCount) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            // The "pop": a brief overshoot when a hold lands.
            KeyframeTrack {
                SpringKeyframe(1.035, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.28)
            }
        }
        .onTapGesture(count: 2) {
            if style == .track { onOpen() }
        }
        .onTapGesture {
            if style == .track { cycleStat() }
        }
        .onLongPressGesture(minimumDuration: SweepFill.holdDuration, maximumDistance: 24) {
            commitHold()
        } onPressingChanged: { pressing in
            holdChanged(pressing: pressing)
        }
        .sensoryFeedback(.success, trigger: successCount)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: softCount)
        .animation(.easeInOut(duration: 0.2), value: status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(task.name), \(CardStatusFormatter.periodName(rules.period)), \(status.value) \(status.caption)")
        .accessibilityAction(named: "Log one") { commitHold() }
        .accessibilityAction(named: "Open details") { onOpen() }
    }

    // MARK: Fill

    @ViewBuilder
    private var fill: some View {
        if !rules.isScored {
            // No limit: no standing fill; a hold sweeps across and lands.
            SLFill(fraction: 0, sections: 1, phase: phase)
        } else if rules.kind == .do {
            SLFill(
                fraction: min(Double(count) / Double(rules.doTarget), 1),
                sections: rules.doTarget,
                phase: phase
            )
        } else {
            // Avoid: full but very faint while clear, red once logged.
            SLFill(fraction: 1, tone: .faint)
            SLFill(fraction: count > 0 ? 1 : 0, sections: 1, phase: phase, tone: .alert)
        }
    }

    // MARK: Gestures

    private func cycleStat() {
        task.quickStat = CardStatusFormatter.nextStat(
            after: shownStat,
            rules: rules,
            streakEmphasis: settings.streakEmphasis
        )
        try? context.save()
    }

    /// While the finger is down the fill advances toward the next step,
    /// fast at first and easing out. Lifting early drains it back.
    private func holdChanged(pressing: Bool) {
        if pressing {
            guard canLog, animatesHold else { return }
            withAnimation(.easeOut(duration: SweepFill.holdDuration)) {
                phase = 1
            }
        } else if phase != 0 {
            withAnimation(.easeOut(duration: 0.25)) {
                phase = 0
            }
        }
    }

    /// The hold arrived: save the entry, pop, and play the haptic.
    private func commitHold() {
        let store = EntryStore(context: context, clock: clock, weekStart: settings.weekStart)
        let result = try? store.logOne(for: task)

        // The saved count now covers what the hold was showing.
        var instant = Transaction()
        instant.disablesAnimations = !reduceMotion
        withTransaction(instant) {
            phase = 0
        }

        switch result {
        case .logged:
            successCount += 1
            if animatesHold { popCount += 1 }
            router.dataChanged()
        case .atTarget:
            softCount += 1
        case nil:
            break
        }
    }
}

/// The settings a card needs, as a value, so the card does not query them.
struct TrackSettings: Equatable {
    var weekStart = 1
    var streakEmphasis = true
    var effectsEnabled = true

    init() {}

    init(_ settings: AppSettings?) {
        guard let settings else { return }
        weekStart = settings.weekStart
        streakEmphasis = settings.streakEmphasis
        effectsEnabled = settings.effectsEnabled
    }
}
