import SwiftData
import SwiftUI

@main
struct MangaMiningApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(settings)
                .modelContainerMigrationGuard()
        }
        .modelContainer(for: [
            CapturedPage.self,
            Sentence.self,
            Cloze.self,
            ClozeQuestion.self,
            WordCard.self,
            ReviewEvent.self
        ])
    }
}

private struct MigrationGuard: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var didRun = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !didRun else { return }
            didRun = true
            LemmaMigration.runIfNeeded(modelContext)
        }
    }
}

private extension View {
    func modelContainerMigrationGuard() -> some View {
        modifier(MigrationGuard())
    }
}
