import CoreML
import UIKit
import Vision

@Observable
@MainActor
final class DetectorViewModel {

    var errorMessage: String? = nil

    // Last measured timing breakdown — populated on every detect() call,
    // read by the benchmark runner.
    var lastTiming: Benchmark.Timing?

    @ObservationIgnored private var vnModel: VNCoreMLModel?

    // Drops to a mock when no model is bundled. Lets the picker UI be
    // developed and tested before the YOLO-World .mlpackage is exported.
    @ObservationIgnored private var usingMock: Bool { vnModel == nil }

    init() {
        loadModel()
    }

    // MARK: - Load Model

    private func loadModel() {
        // Look for FishDetector.mlmodelc — Xcode compiles any `.mlpackage`
        // or `.mlmodel` named "FishDetector" down to this form at build
        // time. To wire in your real model: drag FishDetector.mlpackage
        // into the Xcode project (Targets: DeepScan, Copy if needed).
        guard let url = Bundle.main.url(forResource: "FishDetector", withExtension: "mlmodelc") else {
            print("⚠️ FishDetector.mlmodelc not found in bundle — using mock detections.")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let mlModel = try MLModel(contentsOf: url, configuration: config)
            vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ Detector loaded successfully")
        } catch {
            print("❌ Detector failed to load: \(error)")
            errorMessage = "Failed to load detector: \(error.localizedDescription)"
        }
    }

    // MARK: - Detect

    // Returns at most 8 detected fish, sorted by box area (largest first),
    // with normalized boxes in UIImage convention (top-left origin).
    func detect(image: UIImage) async -> [DetectedFish] {

        if usingMock {
            return mockDetections()
        }

        guard let vnModel, let cgImage = image.cgImage else {
            return []
        }

        var timing = Benchmark.Timing()

        // --- Preprocess: Vision handler + request setup ---
        let preprocessStart = Benchmark.now()

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let request = VNCoreMLRequest(model: vnModel)
        // Object detectors expect aspect-preserving resizing; .scaleFill
        // would distort and tank accuracy.
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )

        timing.preprocessMs = Benchmark.msSince(preprocessStart)

        do {
            // --- Inference: Vision handler.perform() ---
            let inferenceStart = Benchmark.now()

            let observations: [VNRecognizedObjectObservation] = try await Task.detached(priority: .userInitiated) {
                try handler.perform([request])
                return request.results as? [VNRecognizedObjectObservation] ?? []
            }.value

            timing.inferenceMs = Benchmark.msSince(inferenceStart)

            // --- Postprocess: filter, convert coords, sort, truncate ---
            let postprocessStart = Benchmark.now()

            let detections = observations
                .filter { $0.confidence >= 0.25 }
                .map { obs in
                    // Vision uses bottom-left origin; flip Y so downstream
                    // SwiftUI / UIImage code can use the box as-is.
                    let v = obs.boundingBox
                    let topLeft = CGRect(
                        x: v.minX,
                        y: 1 - v.maxY,
                        width: v.width,
                        height: v.height
                    )
                    return DetectedFish(
                        boundingBox: topLeft,
                        confidence: Double(obs.confidence)
                    )
                }
                .sorted { $0.area > $1.area }
                .prefix(8)
                .map { $0 }

            timing.postprocessMs = Benchmark.msSince(postprocessStart)
            lastTiming = timing

            print(String(
                format: "⏱  [detector  ] pre=%.2fms inf=%.2fms post=%.2fms total=%.2fms mem=%.1fMB  boxes=%d",
                timing.preprocessMs, timing.inferenceMs, timing.postprocessMs,
                timing.totalMs, Benchmark.residentMemoryMB(), detections.count
            ))

            return detections

        } catch {
            print("❌ Detection error: \(error)")
            errorMessage = "Detection failed: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Mock

    private func mockDetections() -> [DetectedFish] {
        [
            DetectedFish(boundingBox: CGRect(x: 0.10, y: 0.18, width: 0.30, height: 0.26), confidence: 0.92),
            DetectedFish(boundingBox: CGRect(x: 0.55, y: 0.40, width: 0.28, height: 0.22), confidence: 0.78),
            DetectedFish(boundingBox: CGRect(x: 0.30, y: 0.65, width: 0.25, height: 0.20), confidence: 0.61),
        ]
    }

}
