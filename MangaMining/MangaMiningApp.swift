import SwiftData
import SwiftUI

@main
struct MangaMiningApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [CapturedPage.self, Sentence.self])
    }
}
