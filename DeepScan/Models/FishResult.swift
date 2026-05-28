import UIKit

struct FishResult {
    let fishName: String
    let confidence: Double
    let image: UIImage

    static func mock(image: UIImage) -> FishResult {
        FishResult(
            fishName: "Amphiprion ocellaris",
            confidence: 0.9423,
            image: image
        )
    }
}
