import SwiftUI

@main
struct SystemPulseApp: App {
    @StateObject private var monitor = PerformanceMonitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var monitor: PerformanceMonitor

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "memorychip")
            Text(monitor.frontAppMemoryString)
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundColor(monitor.cameraInUse ? .green : .red)
            Image(systemName: "cpu")
            Text(String(format: "%.0f%%", monitor.frontAppCPUPercent))
            Image(systemName: "battery.100")
            Text("\(monitor.batteryHealthPercent)%")
            Image(systemName: "network")
            Text(monitor.networkSpeedString)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
    }
}
