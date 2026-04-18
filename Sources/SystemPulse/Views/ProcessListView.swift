import SwiftUI
import AppKit

struct ProcessListView: View {
    @ObservedObject var monitor: PerformanceMonitor
    @State private var rows: [ProcessRow] = []
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processes (top 10 by RAM)")
                .font(.headline)
            Divider()
            Table(rows) {
                TableColumn("PID") { r in Text("\(r.pid)").font(.system(.caption, design: .monospaced)) }
                    .width(60)
                TableColumn("Name") { r in Text(r.name).lineLimit(1) }
                TableColumn("RAM") { r in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(r.memoryBytes), countStyle: .memory))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(90)
                TableColumn("CPU") { r in
                    Text(String(format: "%.1f%%", r.cpuPercent))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(70)
                TableColumn("") { r in
                    HStack(spacing: 4) {
                        Button("Kill") { _ = monitor.processes.kill(pid: r.pid) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        Button("Force") { _ = monitor.processes.kill(pid: r.pid, force: true) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(.red)
                    }
                }
                .width(110)
            }
            .frame(minHeight: 320)
        }
        .padding(14)
        .frame(width: 620, height: 440)
        .onAppear {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in refresh() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    @MainActor
    private func refresh() {
        rows = monitor.processes.topProcesses(limit: 10)
    }
}
