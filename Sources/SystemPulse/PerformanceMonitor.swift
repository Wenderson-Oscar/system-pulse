import Foundation
import SwiftUI
import Combine

@MainActor
final class PerformanceMonitor: ObservableObject {
    // Battery
    @Published var batteryHealthPercent: Int = 0
    @Published var batteryCycleCount: Int = 0

    // Frontmost app
    @Published var frontAppName: String = "—"
    @Published var frontAppMemoryBytes: UInt64 = 0
    @Published var frontAppCPUPercent: Double = 0
    @Published var frontAppEnergyMW: Double = 0

    // Network
    @Published var downloadMbps: Double = 0
    @Published var uploadMbps: Double = 0

    // System RAM
    @Published var systemMemory: SystemMemoryInfo = SystemMemoryInfo(totalBytes: 0, usedBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0, freeBytes: 0)

    // GPU (system-wide)
    @Published var gpus: [GPUInfo] = []

    // Fans
    @Published var fans: [SMCMonitor.Fan] = []

    // Camera
    @Published var cameraInUse: Bool = false

    // Lag
    @Published var lagMs: Double = 0
    @Published var lagPeakMs: Double = 0

    private let battery = BatteryMonitor()
    private let memory = MemoryMonitor()
    private let network = NetworkMonitor()
    private let systemMemoryMonitor = SystemMemoryMonitor()
    private let gpu = GPUMonitor()
    private let smc = SMCMonitor()
    private let camera = CameraMonitor()
    private let lag = LagMonitor()

    let processes = ProcessListMonitor()
    let fileScanner = FileScanner()

    private var timer: Timer?

    init() {
        lag.start()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    var frontAppMemoryString: String {
        ByteCountFormatter.string(fromByteCount: Int64(frontAppMemoryBytes), countStyle: .memory)
    }

    var networkSpeedString: String {
        String(format: "%.1f↓ %.1f↑", downloadMbps, uploadMbps)
    }

    private func refresh() {
        let b = battery.read()
        batteryHealthPercent = b.healthPercent
        batteryCycleCount = b.cycleCount

        let m = memory.readFrontmostApp()
        frontAppName = m.name
        frontAppMemoryBytes = m.memoryBytes
        frontAppCPUPercent = m.cpuPercent
        frontAppEnergyMW = m.energyMilliwatts

        let n = network.sample()
        downloadMbps = n.downloadMbps
        uploadMbps = n.uploadMbps

        systemMemory = systemMemoryMonitor.read()

        gpus = gpu.read()

        fans = smc.readFans()
        cameraInUse = camera.isCameraInUse()

        let l = lag.snapshot()
        lagMs = l.currentMs
        lagPeakMs = l.peakMs
    }

    func resetLagPeak() {
        lag.resetPeak()
        lagPeakMs = 0
    }
}
