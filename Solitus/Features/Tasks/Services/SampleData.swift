#if DEBUG
import Foundation
import SwiftData

/// Debug-only sample tasks matching the ones drawn in the mockups
/// (`design/mockups/Main.dc.html`), with about four months of invented
/// history so averages, streaks and heat have something to show.
///
/// Installed only when the app is launched with the `-seedSampleData`
/// argument and the store has no tasks. Never compiled into release builds.
enum SampleData {
    static let launchArgument = "-seedSampleData"
    static let historyDays = 120

    private struct Seed {
        var name: String
        var symbol: String
        var kind: TaskKind = .do
        var period: TaskPeriod = .daily
        var goalMode: GoalMode = .exactly
        var target: Int = 1
        var unit: String?
        /// Slot times in minutes after midnight (daily tasks only).
        var slotMinutes: [Int] = []
        /// Chance, in percent, that one repetition was done on a past day
        /// (or, for Avoid tasks, that an occurrence was logged).
        var chancePercent: Int
        /// Today's count as shown in the Track mockup.
        var todayCount: Int
    }

    private static let seeds: [Seed] = [
        Seed(name: "Drinks", symbol: "wineglass", kind: .avoid, goalMode: .atMost, target: 0, chancePercent: 25, todayCount: 2),
        Seed(name: "Medication", symbol: "pills", target: 3, slotMinutes: [8 * 60, 14 * 60, 21 * 60], chancePercent: 90, todayCount: 1),
        Seed(name: "Gym", symbol: "dumbbell", period: .weekly, target: 4, chancePercent: 45, todayCount: 0),
        Seed(name: "Walk", symbol: "figure.walk", chancePercent: 70, todayCount: 0),
        Seed(name: "Read", symbol: "book", chancePercent: 55, todayCount: 0),
        Seed(name: "Budget review", symbol: "dollarsign.circle", period: .monthly, chancePercent: 3, todayCount: 0),
        Seed(name: "Journal", symbol: "pencil", goalMode: .noLimit, chancePercent: 40, todayCount: 1),
        Seed(name: "Tobacco", symbol: "nosign", kind: .avoid, goalMode: .atMost, target: 0, chancePercent: 6, todayCount: 0),
        Seed(name: "Stretch", symbol: "figure.flexibility", chancePercent: 80, todayCount: 1),
        Seed(name: "Water", symbol: "drop", goalMode: .atLeast, target: 8, unit: "glasses", chancePercent: 85, todayCount: 8),
    ]

    /// Small fixed-seed generator so the sample history is the same on every
    /// launch.
    private struct Generator {
        var state: UInt64

        mutating func nextPercent() -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % 100)
        }
    }

    /// Installs the sample tasks if the launch argument is present and no
    /// task exists yet.
    static func installIfRequested(context: ModelContext, clock: any AppClock = SystemClock()) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<TaskItem>())) ?? 0
        guard existing == 0 else { return }
        install(context: context, clock: clock)
    }

    /// Inserts the sample tasks unconditionally.
    static func install(context: ModelContext, clock: any AppClock) {
        let today = clock.today
        let firstDay = today.adding(-historyDays)
        let createdAt = firstDay.date(in: clock.calendar) ?? clock.now
        var generator = Generator(state: 20_261_120)

        for (order, seed) in seeds.enumerated() {
            let task = TaskItem(
                name: seed.name,
                symbol: seed.symbol,
                kind: seed.kind,
                period: seed.period,
                goalMode: seed.goalMode,
                target: seed.target,
                unit: seed.unit,
                sortOrder: order,
                createdAt: createdAt
            )
            context.insert(task)

            for (index, minutes) in seed.slotMinutes.enumerated() {
                let slot = Slot(index: index, minutes: minutes)
                context.insert(slot)
                task.slots.append(slot)
            }

            // Past days.
            let repetitions = seed.kind == .do && seed.goalMode != .noLimit && seed.period == .daily ? max(seed.target, 1) : 1
            for offset in stride(from: historyDays, through: 1, by: -1) {
                var count = 0
                for _ in 0..<repetitions {
                    if generator.nextPercent() < seed.chancePercent {
                        count += 1
                    }
                }
                if count > 0 {
                    let entry = Entry(dayKey: today.adding(-offset).string, count: count, updatedAt: clock.now)
                    context.insert(entry)
                    task.entries.append(entry)
                }
            }

            // Today, as drawn in the mockup.
            if seed.todayCount > 0 {
                let entry = Entry(dayKey: today.string, count: seed.todayCount, updatedAt: clock.now)
                context.insert(entry)
                task.entries.append(entry)
            }
        }
        try? context.save()
    }
}
#endif
