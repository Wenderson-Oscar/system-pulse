import Foundation
import Darwin

struct SystemMemoryInfo {
    var totalBytes: UInt64
    var usedBytes: UInt64
    var activeBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64
    var freeBytes: UInt64

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

final class SystemMemoryMonitor {
    func read() -> SystemMemoryInfo {
        let total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return SystemMemoryInfo(totalBytes: total, usedBytes: 0, activeBytes: 0,
                                    wiredBytes: 0, compressedBytes: 0, freeBytes: 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        // "Used" as shown by Activity Monitor ≈ active + wired + compressed
        let used = active + wired + compressed

        return SystemMemoryInfo(totalBytes: total, usedBytes: used, activeBytes: active,
                                wiredBytes: wired, compressedBytes: compressed, freeBytes: free)
    }
}
