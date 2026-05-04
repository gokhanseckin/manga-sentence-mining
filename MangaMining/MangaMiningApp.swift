import SwiftData
import SwiftUI

@main
struct MangaMiningApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(settings)
        }
        .modelContainer(for: [
            CapturedPage.self,
            Sentence.self,
            Cloze.self,
            ClozeQuestion.self,
            ReviewEvent.self
        ])
    }
}
