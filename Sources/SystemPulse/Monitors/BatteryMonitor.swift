import Foundation
import IOKit
import IOKit.ps

struct BatteryInfo {
    var healthPercent: Int
    var cycleCount: Int
}

final class BatteryMonitor {
    func read() -> BatteryInfo {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            return BatteryInfo(healthPercent: 0, cycleCount: 0)
        }
        defer { IOObjectRelease(service) }

        let design = intProperty(service, key: "DesignCapacity")
        let maxCap = intProperty(service, key: "AppleRawMaxCapacity") ?? intProperty(service, key: "MaxCapacity")
        let cycles = intProperty(service, key: "CycleCount") ?? 0

        var health = 0
        if let d = design, let m = maxCap, d > 0 {
            health = Int((Double(m) / Double(d)) * 100.0)
        }
        return BatteryInfo(healthPercent: health, cycleCount: cycles)
    }

    private func intProperty(_ service: io_service_t, key: String) -> Int? {
        guard let prop = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        if let n = prop as? Int { return n }
        if let n = prop as? NSNumber { return n.intValue }
        return nil
    }
}
