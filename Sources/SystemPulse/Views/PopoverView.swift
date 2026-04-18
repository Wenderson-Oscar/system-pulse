import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: PerformanceMonitor
    @State private var purgeStatus: String? = nil
    @State private var showPurgeConfirm = false
    @State private var showLagResetConfirm = false
    @State private var netPeakMbps: Double = 10
    @State private var showAbout = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Text("Performance Monitor")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Button {
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("About SystemPulse")
                    .sheet(isPresented: $showAbout) {
                        AboutView()
                    }
                }

                Divider()

                // Foreground app
                compactSection(icon: "memorychip", title: monitor.frontAppName) {
                    HStack(spacing: 12) {
                        miniStat("RAM", value: monitor.frontAppMemoryString)
                        miniStat("CPU", value: String(format: "%.1f%%", monitor.frontAppCPUPercent))
                    }
                }

                // System RAM
                compactBar(
                    icon: "memorychip.fill",
                    title: "RAM",
                    value: String(format: "%.0f%%", monitor.systemMemory.usedPercent),
                    progress: monitor.systemMemory.usedPercent / 100,
                    tint: monitor.systemMemory.usedPercent > 85 ? .red : (monitor.systemMemory.usedPercent > 65 ? .orange : .accentColor),
                    detail: {
                        let fmt: (UInt64) -> String = { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .memory) }
                        let m = monitor.systemMemory
                        return "\(fmt(m.usedBytes))/\(fmt(m.totalBytes)) · A \(fmt(m.activeBytes)) W \(fmt(m.wiredBytes)) C \(fmt(m.compressedBytes))"
                    }()
                )

                // GPU
                let gpuUsage = monitor.gpus.map(\.utilizationPercent).max() ?? 0
                compactBar(
                    icon: "cpu.fill",
                    title: "GPU",
                    value: String(format: "%.0f%%", gpuUsage),
                    progress: min(gpuUsage, 100) / 100,
                    tint: gpuUsage > 85 ? .red : (gpuUsage > 60 ? .orange : .accentColor)
                )

                // Latency
                compactBar(
                    icon: "gauge.with.dots.needle.67percent",
                    title: "Interface Latency",
                    value: String(format: "%.1f ms", monitor.lagMs),
                    progress: min(monitor.lagMs, 100) / 100,
                    tint: monitor.lagMs > 50 ? .red : (monitor.lagMs > 16 ? .orange : .green),
                    detail: String(format: "Peak: %.1f ms", monitor.lagPeakMs)
                )

                // Fans
                if !monitor.fans.isEmpty {
                    compactSection(icon: "fan", title: "Fans") {
                        VStack(spacing: 4) {
                            ForEach(Array(monitor.fans.enumerated()), id: \.offset) { _, f in
                                let maxR = max(Double(f.maxRPM), 1)
                                let pct = Double(f.actualRPM) / maxR
                                HStack(spacing: 6) {
                                    Text("F\(f.index)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 18, alignment: .leading)
                                    ProgressView(value: min(pct, 1))
                                        .progressViewStyle(.linear)
                                        .tint(pct > 0.8 ? .red : (pct > 0.5 ? .orange : .accentColor))
                                    Text("\(f.actualRPM)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                    }
                }

                // Network
                compactSection(icon: "network", title: "Network") {
                    VStack(spacing: 3) {
                        let peak = max(netPeakMbps, monitor.downloadMbps, monitor.uploadMbps, 1)
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down").font(.system(size: 8)).foregroundColor(.blue)
                            ProgressView(value: min(monitor.downloadMbps, peak), total: peak)
                                .progressViewStyle(.linear).tint(.blue)
                            Text(String(format: "%.1f", monitor.downloadMbps))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up").font(.system(size: 8)).foregroundColor(.purple)
                            ProgressView(value: min(monitor.uploadMbps, peak), total: peak)
                                .progressViewStyle(.linear).tint(.purple)
                            Text(String(format: "%.1f", monitor.uploadMbps))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        Text("Mbps")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .onChange(of: monitor.downloadMbps) { v in if v > netPeakMbps { netPeakMbps = v } }
                    .onChange(of: monitor.uploadMbps) { v in if v > netPeakMbps { netPeakMbps = v } }
                }

                // Battery
                let health = Double(monitor.batteryHealthPercent)
                compactBar(
                    icon: "battery.100.bolt",
                    title: "Battery",
                    value: "\(monitor.batteryHealthPercent)%",
                    progress: health / 100,
                    tint: health < 60 ? .red : (health < 80 ? .orange : .green),
                    detail: "Health: \(monitor.batteryHealthPercent)% · \(monitor.batteryCycleCount) cycles"
                )

                // Camera
                compactSection(icon: monitor.cameraInUse ? "video.fill" : "video.slash",
                               title: "Camera") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(monitor.cameraInUse ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(monitor.cameraInUse ? "Active (recording)" : "Inactive")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(monitor.cameraInUse ? .green : .red)
                    }
                }

                Divider()

                // Actions
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actions").font(.system(size: 10, weight: .semibold))
                    HStack(spacing: 6) {
                        compactButton("Processes", icon: "list.bullet.rectangle") {
                            ToolWindows.showProcesses(monitor: monitor)
                        }
                        compactButton("Files", icon: "doc.text.magnifyingglass") {
                            ToolWindows.showHeavyFiles(monitor: monitor)
                        }
                        compactButton("Purge", icon: "arrow.triangle.2.circlepath.circle") {
                            showPurgeConfirm = true; showLagResetConfirm = false
                        }
                        compactButton("Lag ↺", icon: "arrow.counterclockwise") {
                            showLagResetConfirm = true; showPurgeConfirm = false
                        }
                    }
                    .controlSize(.small)

                    if showPurgeConfirm {
                        confirmationPanel(
                            title: "Purge RAM?",
                            message: "Runs /usr/sbin/purge. Requires admin password.",
                            confirmLabel: "Purge", destructive: true
                        ) {
                            showPurgeConfirm = false
                            purgeStatus = "Running…"
                            DispatchQueue.global().async {
                                let msg = SystemActions.purgeRAM()
                                DispatchQueue.main.async { purgeStatus = msg }
                            }
                        } onCancel: { showPurgeConfirm = false }
                    }
                    if showLagResetConfirm {
                        confirmationPanel(
                            title: "Reset lag peak?",
                            message: "Resets the peak value to 0 ms.",
                            confirmLabel: "Reset", destructive: false
                        ) {
                            monitor.resetLagPeak(); showLagResetConfirm = false
                        } onCancel: { showLagResetConfirm = false }
                    }
                    if let s = purgeStatus {
                        Text(s).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.borderless).foregroundColor(.red).font(.system(size: 11))
                }
            }
            .padding(12)
        }
        .frame(width: 300, height: 520)
    }

    // MARK: - Compact Components

    @ViewBuilder
    private func compactBar(icon: String, title: String, value: String, progress: Double, tint: Color, detail: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Text(value).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                }
                ProgressView(value: max(0, min(progress, 1)))
                    .progressViewStyle(.linear).tint(tint)
                    .scaleEffect(y: 0.7)
                if let d = detail {
                    Text(d).font(.system(size: 8, design: .monospaced)).foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
    }

    @ViewBuilder
    private func compactSection(icon: String, title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                content()
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func miniStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 8, weight: .medium)).foregroundColor(.secondary.opacity(0.7))
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func compactButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 9))
                .labelStyle(.titleOnly)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func confirmationPanel(title: String, message: String, confirmLabel: String, destructive: Bool,
                                    onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold))
            Text(message).font(.system(size: 9)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel", action: onCancel).buttonStyle(.bordered).controlSize(.mini)
                Spacer()
                Button(confirmLabel, action: onConfirm).buttonStyle(.borderedProminent).controlSize(.mini)
                    .tint(destructive ? .red : .accentColor)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}
