import SwiftUI

/// Task details (DESIGN.md 7.3), pushed from a card.
///
/// Phase 2: only the title. The screen is built in phase 3.
struct TaskDetailView: View {
    let task: TaskItem

    var body: some View {
        SLScreen {
            SLScreenTitle(task.name)
        }
    }
}
