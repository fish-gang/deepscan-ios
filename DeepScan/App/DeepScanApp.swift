import SwiftUI
import SwiftData

@main
struct DeepScanApp: App {

    // Created once here — model loads at app launch, not per classification.
    @StateObject private var classifier = ClassifierViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(classifier)
        }
        .modelContainer(for: DiaryEntry.self)
    }
}
