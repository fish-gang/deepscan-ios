import CoreML
import UIKit
import Vision

@Observable
@MainActor
final class ClassifierViewModel {

    var result: FishResult? = nil
    var isClassifying = false
    var errorMessage: String? = nil

    // Last measured timing breakdown — read by the benchmark runner after
    // each classify() call. Exposed instead of returning timing from the
    // function so callers that don't care keep the existing API.
    var lastTiming: Benchmark.Timing?

    @ObservationIgnored private var vnModel: VNCoreMLModel?

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
        var timing = Benchmark.Timing()

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

        // --- Preprocess: cgImage extraction + Vision handler setup ---
        let preprocessStart = Benchmark.now()

        guard let cgImage = image.cgImage else {
            print("❌ Could not get CGImage from UIImage")
            errorMessage = "Failed to process image."
            isClassifying = false
            return nil
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )

        timing.preprocessMs = Benchmark.msSince(preprocessStart)

        do {
            // --- Inference: Vision handler.perform() (includes Vision's
            //     internal resize/normalize + the model forward pass on
            //     CPU/GPU/Neural Engine, whichever computeUnits selected) ---
            let inferenceStart = Benchmark.now()

            let observations: [VNClassificationObservation] = try await Task.detached(priority: .userInitiated) {
                try handler.perform([request])
                return request.results as? [VNClassificationObservation] ?? []
            }.value

            timing.inferenceMs = Benchmark.msSince(inferenceStart)

            // --- Postprocess: softmax + result construction ---
            let postprocessStart = Benchmark.now()

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

            print("✅ Top: \(top.identifier), confidence: \(confidence)")

            let fishResult = FishResult(
                fishName: displayName(for: top.identifier),
                confidence: confidence,
                image: image
            )
            result = fishResult

            timing.postprocessMs = Benchmark.msSince(postprocessStart)
            lastTiming = timing

            print(String(
                format: "⏱  [classifier] pre=%.2fms inf=%.2fms post=%.2fms total=%.2fms mem=%.1fMB",
                timing.preprocessMs, timing.inferenceMs, timing.postprocessMs,
                timing.totalMs, Benchmark.residentMemoryMB()
            ))

            isClassifying = false
            return fishResult

        } catch {
            print("❌ Classification error: \(error)")
            errorMessage = "Classification failed: \(error.localizedDescription)"
        }

        isClassifying = false
        return nil
    }

    // MARK: - Display Name

    // Transforms the raw model label into binomial scientific-name display
    // form: replace underscore with space, capitalize the first letter only.
    // e.g. `acanthurus_coeruleus` → `Acanthurus coeruleus`,
    //      `no_fish` → `No fish`, `unknown_fish` → `Unknown fish`.
    private func displayName(for identifier: String) -> String {
        let spaced = identifier.replacingOccurrences(of: "_", with: " ")
        guard let first = spaced.first else { return spaced }
        return first.uppercased() + spaced.dropFirst()
    }
}
