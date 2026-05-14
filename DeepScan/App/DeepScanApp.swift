import SwiftUI
import SwiftData

@main
struct DeepScanApp: App {

    // Created once here — models load at app launch, not per request.
    @State private var classifier = ClassifierViewModel()
    @State private var detector = DetectorViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(classifier)
                .environment(detector)
        }
        .modelContainer(for: DiaryEntry.self)
    }
}
