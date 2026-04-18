import Foundation
import Darwin
import AppKit

struct ProcessRow: Identifiable, Hashable {
    var id: pid_t { pid }
    var pid: pid_t
    var name: String
    var memoryBytes: UInt64
    var cpuPercent: Double
}

final class ProcessListMonitor {
    private var lastCPUns: [pid_t: UInt64] = [:]
    private var lastTime: TimeInterval = 0

    /// Returns top-N processes by memory usage.
    func topProcesses(limit: Int = 10) -> [ProcessRow] {
        let pids = allPIDs()
        let now = Date().timeIntervalSince1970
        let dt = lastTime > 0 ? (now - lastTime) : 1.0

        var rows: [ProcessRow] = []
        var newCPU: [pid_t: UInt64] = [:]

        for pid in pids where pid > 0 {
            var usage = rusage_info_current()
            let ok = withUnsafeMutablePointer(to: &usage) { ptr -> Int32 in
                ptr.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) { rebound in
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
                }
            } == 0
            guard ok else { continue }

            var taskInfo = proc_taskinfo()
            let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            let totalCPUns: UInt64 = size > 0 ? taskInfo.pti_total_user + taskInfo.pti_total_system : 0
            newCPU[pid] = totalCPUns

            var cpuPct = 0.0
            if let prev = lastCPUns[pid], totalCPUns >= prev, dt > 0 {
                cpuPct = (Double(totalCPUns - prev) / (dt * 1_000_000_000)) * 100.0
            }

            rows.append(ProcessRow(pid: pid,
                                    name: processName(pid: pid),
                                    memoryBytes: usage.ri_resident_size,
                                    cpuPercent: cpuPct))
        }

        lastCPUns = newCPU
        lastTime = now

        return Array(rows.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(limit))
    }

    func kill(pid: pid_t, force: Bool = false) -> Bool {
        Darwin.kill(pid, force ? SIGKILL : SIGTERM) == 0
    }

    private func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count))
        let size = Int32(count) * Int32(MemoryLayout<pid_t>.size)
        let actual = proc_listallpids(&pids, size)
        return Array(pids.prefix(Int(actual)))
    }

    private func processName(pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid)?.localizedName {
            return app
        }
        var buf = [CChar](repeating: 0, count: 1024)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        if n > 0 { return String(cString: buf) }
        return "pid \(pid)"
    }
}
