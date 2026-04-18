import Foundation
import IOKit

struct GPUInfo {
    var name: String
    var utilizationPercent: Double
    var rendererUtilizationPercent: Double
    var tilerUtilizationPercent: Double
    var vramUsedBytes: UInt64
    var vramTotalBytes: UInt64
}

/// Reads system-wide GPU statistics from IOKit's IOAccelerator service.
/// Per-process GPU usage is not available via public macOS APIs.
final class GPUMonitor {
    func read() -> [GPUInfo] {
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iter) }

        var gpus: [GPUInfo] = []
        while case let service = IOIteratorNext(iter), service != 0 {
            defer { IOObjectRelease(service) }

            let name = serviceName(service) ?? "GPU"
            let stats = property(service, key: "PerformanceStatistics") as? [String: Any] ?? [:]

            // Common keys across Intel / Apple Silicon GPUs
            let util = doubleVal(stats["Device Utilization %"]) ?? doubleVal(stats["GPU Activity(%)"]) ?? 0
            let renderer = doubleVal(stats["Renderer Utilization %"]) ?? 0
            let tiler = doubleVal(stats["Tiler Utilization %"]) ?? 0

            // VRAM: "vramUsedBytes" / "vramFreeBytes" (Intel/AMD)
            // Apple Silicon shares system RAM and doesn't expose these consistently.
            let used = uintVal(stats["vramUsedBytes"]) ?? uintVal(stats["In use system memory"]) ?? 0
            let free = uintVal(stats["vramFreeBytes"]) ?? 0
            let total = used + free

            gpus.append(GPUInfo(
                name: name,
                utilizationPercent: util,
                rendererUtilizationPercent: renderer,
                tilerUtilizationPercent: tiler,
                vramUsedBytes: used,
                vramTotalBytes: total
            ))
        }
        return gpus
    }

    private func property(_ service: io_service_t, key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private func serviceName(_ service: io_service_t) -> String? {
        if let model = property(service, key: "model") {
            if let data = model as? Data, let s = String(data: data, encoding: .utf8) {
                return s.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            }
            if let s = model as? String { return s }
        }
        if let parent = property(service, key: "IOName") as? String { return parent }
        return nil
    }

    private func doubleVal(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        return nil
    }

    private func uintVal(_ v: Any?) -> UInt64? {
        if let n = v as? NSNumber { return n.uint64Value }
        return nil
    }
}
