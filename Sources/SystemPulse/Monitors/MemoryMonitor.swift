import Foundation
import AppKit
import Darwin

struct FrontAppInfo {
    var name: String
    var memoryBytes: UInt64
    var cpuPercent: Double
    var energyMilliwatts: Double
}

final class MemoryMonitor {
    private var lastPID: pid_t = 0
    private var lastCPUns: UInt64 = 0
    private var lastEnergyNJ: UInt64 = 0
    private var lastTime: TimeInterval = 0

    func readFrontmostApp() -> FrontAppInfo {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return FrontAppInfo(name: "—", memoryBytes: 0, cpuPercent: 0, energyMilliwatts: 0)
        }
        let name = app.localizedName ?? "Unknown"
        let pid = app.processIdentifier
        let now = Date().timeIntervalSince1970

        var usage = rusage_info_current()
        let rusageResult = withUnsafeMutablePointer(to: &usage) { ptr -> Int32 in
            ptr.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        let memBytes: UInt64 = rusageResult == 0 ? usage.ri_resident_size : 0
        let energyNJ: UInt64 = rusageResult == 0 ? usage.ri_energy_nj : 0

        var taskInfo = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
        let totalCPUns = size > 0 ? taskInfo.pti_total_user + taskInfo.pti_total_system : 0

        defer {
            lastPID = pid
            lastCPUns = totalCPUns
            lastEnergyNJ = energyNJ
            lastTime = now
        }

        var cpuPercent = 0.0
        var energyMW = 0.0

        if lastTime > 0, lastPID == pid {
            let dt = now - lastTime
            if dt > 0 {
                let wallNs = dt * 1_000_000_000
                let cpuDelta = totalCPUns >= lastCPUns ? Double(totalCPUns - lastCPUns) : 0
                cpuPercent = (cpuDelta / wallNs) * 100.0
                if energyNJ >= lastEnergyNJ {
                    energyMW = (Double(energyNJ - lastEnergyNJ) * 1e-9 / dt) * 1000.0
                }
            }
        }

        return FrontAppInfo(name: name, memoryBytes: memBytes, cpuPercent: cpuPercent, energyMilliwatts: energyMW)
    }
}
