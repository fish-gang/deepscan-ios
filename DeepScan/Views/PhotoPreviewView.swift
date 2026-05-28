import SwiftUI

struct PhotoPreviewView: View {

    let image: UIImage
    let onRetake: () -> Void
    let onScanAnother: () -> Void

    @Environment(ClassifierViewModel.self) private var classifier
    @Environment(DetectorViewModel.self) private var detector

    @State private var phase: ScanPhase = .idle
    @State private var detections: [DetectedFish] = []
    @State private var fishResult: FishResult?
    @State private var navigateToPicker = false
    @State private var navigateToResults = false

    // MARK: - Benchmark State (thesis-only instrumentation)

    @State private var isBenchmarking = false
    @State private var benchmarkProgress: Int = 0
    @State private var benchmarkCSVPath: String?

    private let benchmarkIterations = 30
    private let benchmarkWarmups = 2

    enum ScanPhase: Equatable {
        case idle
        case detecting
        case classifying
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            controlsPanel
        }
        .navigationDestination(isPresented: $navigateToPicker) {
            FishPickerView(
                image: image,
                detections: detections,
                onRetake: onRetake,
                onScanAnother: onScanAnother
            )
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let result = fishResult {
                ResultsView(result: result, onScanAnother: onScanAnother)
            }
        }
    }

    // MARK: - Bottom Controls

    private var controlsPanel: some View {
        VStack(spacing: 12) {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: onRetake) {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.white)
                .disabled(isBusy)

                Button(action: scan) {
                    HStack(spacing: 8) {
                        if isBusy {
                            Image(systemName: "fish.fill")
                                .symbolEffect(.pulse, options: .repeating, isActive: isBusy)
                                .foregroundStyle(.white)
                            Text(busyLabel)
                        } else {
                            Label("Scan Fish", systemImage: "fish.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(OceanTheme.aqua)
                .disabled(isBusy)
            }

            if let error = classifier.errorMessage ?? detector.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // MARK: - Benchmark button (thesis instrumentation)
            Button(action: runBenchmark) {
                Label(
                    isBenchmarking
                        ? "Benchmark \(benchmarkProgress)/\(benchmarkIterations)…"
                        : "Benchmark (\(benchmarkIterations)×)",
                    systemImage: "speedometer"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.white)
            .disabled(isBusy || isBenchmarking)

            if let path = benchmarkCSVPath {
                Text("CSV: \(path)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private var isBusy: Bool {
        phase == .detecting || phase == .classifying
    }

    private var busyLabel: String {
        switch phase {
        case .detecting: return "Detecting..."
        case .classifying: return "Scanning..."
        default: return ""
        }
    }

    private var prompt: String {
        switch phase {
        case .idle:
            return "Does this look good?"
        case .detecting:
            return "Looking for fish..."
        case .classifying:
            return "Identifying species..."
        }
    }

    // MARK: - Scan

    private func scan() {
        phase = .detecting
        Task {
            let found = await detector.detect(image: image)

            switch found.count {
            case 0:
                // Detector found nothing. Either the photo isn't a fish, or
                // the detector missed (common for fish that fill the frame).
                // Either way, hand the whole image to the classifier — its
                // `no_fish` sentinel will catch genuinely non-fish photos.
                await classify(image)

            case 1:
                // Single fish — skip the picker, classify the cropped region.
                let cropped = ImageCrop.crop(image, to: found[0].boundingBox) ?? image
                await classify(cropped)

            default:
                // Multiple fish — let the user pick which one to scan.
                detections = found
                phase = .idle
                navigateToPicker = true
            }
        }
    }

    private func classify(_ imageToClassify: UIImage) async {
        phase = .classifying
        if let result = await classifier.classify(image: imageToClassify) {
            fishResult = result
            navigateToResults = true
        }
        phase = .idle
    }

    // MARK: - Benchmark (Chapter 6.3.1 / 6.3.2)

    // Runs the full detect → crop → classify pipeline N times on the same
    // image and prints per-iteration timings + summary stats. Also writes
    // a CSV file to Documents so we can pull it off the device for analysis.
    //
    // Per iteration we log:
    //   - detect_pre_ms / detect_inf_ms / detect_post_ms / detect_total_ms
    //   - crop_ms
    //   - classify_pre_ms / classify_inf_ms / classify_post_ms / classify_total_ms
    //   - end_to_end_ms
    //   - resident_mb (phys_footprint)
    private func runBenchmark() {
        guard !isBenchmarking else { return }
        isBenchmarking = true
        benchmarkProgress = 0
        benchmarkCSVPath = nil

        let totalIterations = benchmarkIterations
        let warmups = benchmarkWarmups

        Task {
            print("════════ BENCHMARK START ════════")
            print("device: iPhone (target iOS 26.2+) · iterations=\(totalIterations) · warmup=\(warmups)")
            print("image size: \(Int(image.size.width))×\(Int(image.size.height))px")
            print("baseline memory: \(String(format: "%.1f", Benchmark.residentMemoryMB())) MB")

            // --- Warmup (not measured) ---
            for w in 1...warmups {
                _ = await detector.detect(image: image)
                _ = await classifier.classify(image: image)
                print("warmup \(w)/\(warmups) done")
            }

            // --- CSV header (also written to file at the end) ---
            let header = "iter,detect_pre_ms,detect_inf_ms,detect_post_ms,detect_total_ms,crop_ms,classify_pre_ms,classify_inf_ms,classify_post_ms,classify_total_ms,end_to_end_ms,resident_mb"
            print("[BM_CSV] \(header)")
            var csvLines: [String] = [header]

            // --- Measured iterations ---
            var detInf: [Double] = []
            var clsInf: [Double] = []
            var ends:   [Double] = []
            var memSamples: [Double] = []

            for i in 1...totalIterations {
                let e2eStart = Benchmark.now()

                // Detector
                let detections = await detector.detect(image: image)
                let dT = detector.lastTiming ?? Benchmark.Timing()

                // Crop (only if we have detections)
                let cropStart = Benchmark.now()
                let toClassify: UIImage
                if let first = detections.first,
                   let cropped = ImageCrop.crop(image, to: first.boundingBox) {
                    toClassify = cropped
                } else {
                    toClassify = image
                }
                let cropMs = Benchmark.msSince(cropStart)

                // Classifier
                _ = await classifier.classify(image: toClassify)
                let cT = classifier.lastTiming ?? Benchmark.Timing()

                let e2e = Benchmark.msSince(e2eStart)
                let mem = Benchmark.residentMemoryMB()

                detInf.append(dT.inferenceMs)
                clsInf.append(cT.inferenceMs)
                ends.append(e2e)
                memSamples.append(mem)

                let line = String(
                    format: "%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f",
                    i,
                    dT.preprocessMs, dT.inferenceMs, dT.postprocessMs, dT.totalMs,
                    cropMs,
                    cT.preprocessMs, cT.inferenceMs, cT.postprocessMs, cT.totalMs,
                    e2e, mem
                )
                print("[BM_CSV] \(line)")
                csvLines.append(line)

                benchmarkProgress = i
            }

            // --- Summary stats ---
            let detStats = Benchmark.stats(detInf)
            let clsStats = Benchmark.stats(clsInf)
            let e2eStats = Benchmark.stats(ends)
            let memStats = Benchmark.stats(memSamples)

            let summary = """
            ──────── SUMMARY (n=\(totalIterations), warmups discarded) ────────
            detect.inference   mean=\(fmt(detStats.mean)) median=\(fmt(detStats.median)) p95=\(fmt(detStats.p95)) min=\(fmt(detStats.min)) max=\(fmt(detStats.max)) σ=\(fmt(detStats.stdDev))
            classify.inference mean=\(fmt(clsStats.mean)) median=\(fmt(clsStats.median)) p95=\(fmt(clsStats.p95)) min=\(fmt(clsStats.min)) max=\(fmt(clsStats.max)) σ=\(fmt(clsStats.stdDev))
            end-to-end         mean=\(fmt(e2eStats.mean)) median=\(fmt(e2eStats.median)) p95=\(fmt(e2eStats.p95)) min=\(fmt(e2eStats.min)) max=\(fmt(e2eStats.max)) σ=\(fmt(e2eStats.stdDev))
            resident memory    mean=\(fmt(memStats.mean)) MB · max=\(fmt(memStats.max)) MB · min=\(fmt(memStats.min)) MB
            """
            print(summary)
            csvLines.append("")
            csvLines.append("# " + summary.replacingOccurrences(of: "\n", with: "\n# "))

            // --- Save CSV to Documents so we can pull it off the device ---
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "deepscan_benchmark_\(formatter.string(from: Date())).csv"
            if let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first {
                let url = docs.appendingPathComponent(filename)
                do {
                    try csvLines.joined(separator: "\n").write(
                        to: url, atomically: true, encoding: .utf8
                    )
                    print("📝 CSV saved: \(url.path)")
                    benchmarkCSVPath = filename
                } catch {
                    print("⚠️ CSV write failed: \(error)")
                }
            }

            print("════════ BENCHMARK END ════════")
            isBenchmarking = false
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.2fms", v)
    }
}

#Preview {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 844))
    let fakeImage = renderer.image { ctx in
        UIColor.systemTeal.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 390, height: 844))
    }
    return NavigationStack {
        PhotoPreviewView(image: fakeImage, onRetake: {}, onScanAnother: {})
            .environment(ClassifierViewModel())
            .environment(DetectorViewModel())
    }
}
