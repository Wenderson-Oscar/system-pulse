import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, description: String)] = [
        (
            "memorychip",
            "Active App Monitor",
            "Tracks RAM and CPU usage of the currently focused app in real time."
        ),
        (
            "memorychip.fill",
            "System RAM",
            "Shows total memory usage broken down into active, wired, and compressed segments."
        ),
        (
            "cpu.fill",
            "GPU Monitor",
            "Displays the GPU utilization percentage across all available graphics processors."
        ),
        (
            "gauge.with.dots.needle.67percent",
            "Interface Latency",
            "Measures UI responsiveness in milliseconds and tracks the peak lag value."
        ),
        (
            "fan",
            "Fan Speed",
            "Reports each fan's current RPM relative to its maximum speed."
        ),
        (
            "network",
            "Network",
            "Monitors real-time download and upload throughput in Mbps."
        ),
        (
            "battery.100.bolt",
            "Battery Health",
            "Shows battery health percentage and total charge cycle count."
        ),
        (
            "video",
            "Camera Status",
            "Detects whether the built-in camera is actively being used by any app."
        ),
        (
            "list.bullet.rectangle",
            "Process List",
            "Lists all running processes sorted by CPU or RAM consumption."
        ),
        (
            "doc.text.magnifyingglass",
            "Heavy Files",
            "Scans the file system to identify the largest files consuming disk space."
        ),
        (
            "arrow.triangle.2.circlepath.circle",
            "Purge RAM",
            "Runs the system purge command to free up inactive memory (requires admin password)."
        ),
        (
            "arrow.counterclockwise",
            "Reset Lag Peak",
            "Resets the interface latency peak counter back to zero."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.accentColor)

                Text("SystemPulse")
                    .font(.system(size: 16, weight: .bold))

                Text("Real-time macOS Performance Monitor")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Feature list
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(features, id: \.title) { feature in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                                .frame(width: 20, alignment: .center)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(feature.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            // Footer
            HStack {
                Text("© 2026 SystemPulse")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 320, height: 480)
    }
}
