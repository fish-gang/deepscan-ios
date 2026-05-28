import Foundation
import Darwin

// Lightweight timing + memory helpers used only for thesis-grade
// performance measurements. Designed to add negligible overhead to
// the inference path (a couple of timestamp reads per call).
enum Benchmark {

    // MARK: - Per-call Timing

    struct Timing {
        var preprocessMs: Double = 0
        var inferenceMs: Double = 0
        var postprocessMs: Double = 0
        var totalMs: Double { preprocessMs + inferenceMs + postprocessMs }
    }

    @inline(__always)
    static func now() -> CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }

    @inline(__always)
    static func msSince(_ start: CFAbsoluteTime) -> Double {
        (CFAbsoluteTimeGetCurrent() - start) * 1000
    }

    // MARK: - Memory

    // Resident memory footprint in MB. Mirrors the value Xcode's Memory
    // gauge reports (phys_footprint), so observations line up with
    // what's visible in the IDE while measurements run.
    static func residentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }

    // MARK: - Summary Stats

    struct Stats {
        let count: Int
        let mean: Double
        let median: Double
        let p95: Double
        let min: Double
        let max: Double
        let stdDev: Double
    }

    static func stats(_ values: [Double]) -> Stats {
        guard !values.isEmpty else {
            return Stats(count: 0, mean: 0, median: 0, p95: 0, min: 0, max: 0, stdDev: 0)
        }
        let sorted = values.sorted()
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n

        let median: Double
        if sorted.count.isMultiple(of: 2) {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        // Nearest-rank p95.
        let p95Index = max(0, min(Int(ceil(0.95 * n)) - 1, sorted.count - 1))
        let p95 = sorted[p95Index]

        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / n
        let stdDev = sqrt(variance)

        return Stats(
            count: values.count,
            mean: mean,
            median: median,
            p95: p95,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            stdDev: stdDev
        )
    }
}
