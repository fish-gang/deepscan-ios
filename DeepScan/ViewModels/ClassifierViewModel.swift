import Combine
import CoreML
import UIKit
import Vision

@MainActor
class ClassifierViewModel: ObservableObject {

    @Published var result: FishResult? = nil
    @Published var isClassifying = false
    @Published var errorMessage: String? = nil

    private var vnModel: VNCoreMLModel?

    init() {
        loadModel()
    }

    // MARK: - Load Model

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let coreMLModel = try DeepScanClassifier(configuration: config)
            vnModel = try VNCoreMLModel(for: coreMLModel.model)
            print("✅ Model loaded successfully")
        } catch {
            print("❌ Model failed to load: \(error)")
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    // MARK: - Classify

    // Returns the FishResult directly so callers never read stale @Published state.
    func classify(image: UIImage) async -> FishResult? {
        print("🔍 Starting classification...")
        isClassifying = true
        result = nil
        errorMessage = nil

        guard let vnModel = vnModel else {
            print("❌ Model not loaded")
            errorMessage = "Model not loaded."
            isClassifying = false
            return nil
        }

        guard let cgImage = image.cgImage else {
            print("❌ Could not get CGImage from UIImage")
            errorMessage = "Failed to process image."
            isClassifying = false
            return nil
        }

        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: imageOrientation(from: image),
            options: [:]
        )

        do {
            // Run on background thread to avoid blocking UI.
            // Read request.results inside the task so it's accessed on the
            // same thread where handler.perform ran.
            let observations: [VNClassificationObservation] = try await Task.detached(priority: .userInitiated) {
                try handler.perform([request])
                return request.results as? [VNClassificationObservation] ?? []
            }.value

            guard let top = observations.first else {
                print("❌ No classification results")
                errorMessage = "Could not classify image."
                isClassifying = false
                return nil
            }

            // The model outputs raw logits, not probabilities, so we apply
            // softmax to convert them to a proper [0.0, 1.0] probability.
            let scores = observations.map { Double($0.confidence) }
            let maxScore = scores.max() ?? 0
            let exps = scores.map { exp($0 - maxScore) }
            let confidence = (exps.first ?? 0) / exps.reduce(0, +)
            let isConfident = confidence >= 0.30

            print("✅ Top: \(top.identifier), confidence: \(confidence)")

            let fishResult = FishResult(
                fishName: isConfident ? displayName(for: top.identifier) : "Unknown Species",
                confidence: confidence,
                description: isConfident ? description(for: top.identifier) : "The image did not match any known marine species with sufficient confidence. Try a clearer or closer photo.",
                image: image
            )
            result = fishResult
            isClassifying = false
            return fishResult

        } catch {
            print("❌ Classification error: \(error)")
            errorMessage = "Classification failed: \(error.localizedDescription)"
        }

        isClassifying = false
        return nil
    }

    // MARK: - Image Orientation

    // Vision needs the correct image orientation to process the image correctly.
    // Photos taken in portrait mode have a different orientation flag
    // than landscape — ignoring this causes incorrect classifications.
    private func imageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: - Display Names

    // Maps scientific names (from model labels) to common names
    private func displayName(for scientificName: String) -> String {
        let names: [String: String] = [
            "acanthurus_coeruleus": "Blue Tang",
            "amphiprion_ocellaris": "Clownfish",
            "arothron_meleagris": "Guineafowl Puffer",
            "carcharhinus_melanopterus": "Blacktip Reef Shark",
            "chaetodon_lunula": "Raccoon Butterflyfish",
            "chromis_viridis": "Green Chromis",
            "naso_unicornis": "Bluespine Unicornfish",
            "pomacanthus_imperator": "Emperor Angelfish",
            "pterois_volitans": "Red Lionfish",
            "rhinecanthus_aculeatus": "Picasso Triggerfish",
            "scarus_ghobban": "Bluebarred Parrotfish",
        ]
        return names[scientificName] ?? scientificName
    }

    // MARK: - Descriptions

    // Fun facts for each species shown in ResultsView
    private func description(for scientificName: String) -> String {
        let descriptions: [String: String] = [
            "acanthurus_coeruleus": "Blue Tang — a vibrant reef fish known for its sharp defensive spine near the tail. Found throughout tropical Atlantic waters.",
            "amphiprion_ocellaris": "Clownfish — lives among sea anemone tentacles, protected by a special mucus coating that makes it immune to the anemone's sting.",
            "arothron_meleagris": "Guineafowl Puffer — can inflate its body with water as a defense mechanism. Its skin and organs contain a powerful toxin.",
            "carcharhinus_melanopterus": "Blacktip Reef Shark — recognizable by the black tips on its fins. Generally shy around humans and found in shallow reef waters.",
            "chaetodon_lunula": "Raccoon Butterflyfish — named for its distinctive mask-like facial markings. Feeds on coral polyps and invertebrates.",
            "chromis_viridis": "Green Chromis — one of the most common reef fish. Lives in large schools above coral heads for protection.",
            "naso_unicornis": "Bluespine Unicornfish — named for the horn-like projection on its forehead. Has sharp blue spines near its tail for defense.",
            "pomacanthus_imperator": "Emperor Angelfish — one of the most striking reef fish. Juveniles look completely different from adults with circular white markings.",
            "pterois_volitans": "Red Lionfish — venomous invasive species in the Atlantic. Its spines deliver a painful sting but it is not aggressive.",
            "rhinecanthus_aculeatus": "Picasso Triggerfish — named for its abstract markings resembling a Picasso painting. Can lock its dorsal spine upright for protection.",
            "scarus_ghobban": "Bluebarred Parrotfish — uses its fused beak-like teeth to scrape algae off coral. The white sand on many tropical beaches is partly composed of coral ground up in their digestive systems.",
        ]
        return descriptions[scientificName] ?? "A fascinating marine creature found in tropical coral reef ecosystems."
    }
}
