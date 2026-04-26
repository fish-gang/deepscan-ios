import UIKit

struct FishResult {
    let fishName: String
    let confidence: Double
    let description: String
    let image: UIImage

    static func mock(image: UIImage) -> FishResult {
        FishResult(
            fishName: "Clownfish",
            confidence: 0.94,
            description: "Also known as anemonefish, clownfish live among the tentacles of sea anemones. They are immune to the anemone's sting thanks to a special mucus coating on their skin.",
            image: image
        )
    }
}
