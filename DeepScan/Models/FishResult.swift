import UIKit

// FishResult is a Model - it's just a data container.
// It holds everything we need to display on the results screen.
// Think of it as a DTO (Data Transfer Object) in Java.
struct FishResult {

    // The fish that was identified
    let fishName: String

    // How confident the model is, from 0.0 to 1.0
    // e.g. 0.92 = 92% confident
    let confidence: Double

    // A short fun fact or description about the fish
    let description: String

    // The photo the user took
    let image: UIImage

    // MARK: - Mock Data

    // A static factory method that returns a fake result.
    // 'static' means you call it on the type itself, not an instance.
    // FishResult.mock(image:) - no need to create a FishResult first.
    // We use this while waiting for the real ML model.
    static func mock(image: UIImage) -> FishResult {
        FishResult(
            fishName: "Clownfish",
            confidence: 0.94,
            description: "Also known as anemonefish, clownfish live among the tentacles of sea anemones. They are immune to the anemone's sting thanks to a special mucus coating on their skin.",
            image: image
        )
    }
}
