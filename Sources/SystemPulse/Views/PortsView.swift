import SwiftUI
import AppKit

private struct PortTerminationRequest: Identifiable {
    var row: OpenPortRow
    var force: Bool

    var id: String {
        "\(row.id)-\(force ? "force" : "term")"
    }
}

struct PortsView: View {
    @ObservedObject var monitor: PerformanceMonitor
    var onClose: (() -> Void)? = nil
    @State private var rows: [OpenPortRow] = []
    @State private var selection: OpenPortRow.ID?
    @State private var filterText = ""
    @State private var includeUDP = true
    @State private var isRefreshing = false
    @State private var statusText = "Waiting for first scan"
    @State private var lastUpdated: Date?
    @State private var timer: Timer?
    @State private var terminationRequest: PortTerminationRequest?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    private var filteredRows: [OpenPortRow] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows }

        return rows.filter { row in
            [
                "\(row.port)",
                row.protocolName,
                row.processName,
                "\(row.pid)",
                row.user,
                row.endpoint,
                row.state,
                row.processPath
            ].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var selectedRow: OpenPortRow? {
        guard let selection else { return nil }
        return rows.first { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Open Ports")
                    .font(.headline)

                Text(summaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Toggle("UDP", isOn: $includeUDP)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: includeUDP) { _ in refresh() }

                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
                .controlSize(.small)

                if let onClose {
                    Button {
                        onClose()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .controlSize(.small)
                }
            }

            TextField("Filter ports, process, PID, user", text: $filterText)
                .textFieldStyle(.roundedBorder)

            Divider()

            Table(filteredRows, selection: $selection) {
                TableColumn("Port") { row in
                    Text("\(row.port)")
                        .font(.system(.caption, design: .monospaced))
                }
                .width(70)

                TableColumn("Proto") { row in
                    Text(row.protocolName)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(58)

                TableColumn("Process") { row in
                    Text(row.processName)
                        .lineLimit(1)
                }

                TableColumn("PID") { row in
                    Text("\(row.pid)")
                        .font(.system(.caption, design: .monospaced))
                }
                .width(70)

                TableColumn("User") { row in
                    Text(row.user.isEmpty ? "—" : row.user)
                        .lineLimit(1)
                }
                .width(90)

                TableColumn("Endpoint") { row in
                    Text(row.endpoint)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                }

                TableColumn("State") { row in
                    Text(row.state)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(70)

                TableColumn("") { row in
                    HStack(spacing: 4) {
                        Button {
                            revealExecutable(for: row)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(row.processPath.isEmpty)
                        .help("Reveal executable")

                        Button {
                            terminationRequest = PortTerminationRequest(row: row, force: false)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(.red)
                        .help("Close process")
                    }
                }
                .width(78)
            }
            .frame(minHeight: 300)

            if let row = selectedRow {
                Divider()
                portDetail(row)
            }

            HStack {
                Text(statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(14)
        .frame(width: 820, height: 540)
        .onAppear {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in refresh() }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .alert(item: $terminationRequest) { request in
            Alert(
                title: Text(request.force ? "Force Quit Process?" : "Close Process?"),
                message: Text("This will \(request.force ? "force quit" : "ask") \(request.row.processName) (PID \(request.row.pid)) to exit and will close every port owned by that process."),
                primaryButton: .destructive(Text(request.force ? "Force Quit" : "Close")) {
                    terminate(request)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var summaryText: String {
        let tcp = rows.filter { $0.protocolName == "TCP" }.count
        let udp = rows.filter { $0.protocolName == "UDP" }.count
        return "\(rows.count) total · \(tcp) TCP · \(udp) UDP"
    }

    private var statusLine: String {
        if let lastUpdated {
            return "\(statusText) · Updated \(Self.timeFormatter.string(from: lastUpdated))"
        }
        return statusText
    }

    @ViewBuilder
    private func portDetail(_ row: OpenPortRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(row.processName) · PID \(row.pid)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    revealExecutable(for: row)
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .disabled(row.processPath.isEmpty)
                .controlSize(.small)

                Button {
                    terminationRequest = PortTerminationRequest(row: row, force: false)
                } label: {
                    Label("Close", systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .tint(.red)

                Button {
                    terminationRequest = PortTerminationRequest(row: row, force: true)
                } label: {
                    Label("Force", systemImage: "exclamationmark.triangle")
                }
                .controlSize(.small)
                .tint(.red)
            }

            Text("\(row.protocolName) \(row.endpoint) · \(row.state) · FD \(row.fileDescriptorSummary)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(row.processPath.isEmpty ? "Executable path unavailable" : row.processPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        statusText = "Scanning"
        let includeUDPInScan = includeUDP
        let portMonitor = monitor.ports

        DispatchQueue.global(qos: .userInitiated).async {
            let result = portMonitor.openPorts(includeUDP: includeUDPInScan)

            DispatchQueue.main.async {
                rows = result.rows
                isRefreshing = false
                lastUpdated = Date()

                if let warning = result.warning, !warning.isEmpty {
                    statusText = warning
                } else {
                    statusText = "Live"
                }

                if let selection, !rows.contains(where: { $0.id == selection }) {
                    self.selection = nil
                }
            }
        }
    }

    private func revealExecutable(for row: OpenPortRow) {
        guard !row.processPath.isEmpty else {
            statusText = "Executable path unavailable"
            return
        }

        guard FileManager.default.fileExists(atPath: row.processPath) else {
            statusText = "Executable no longer exists"
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: row.processPath)])
        statusText = "Revealed \(row.processName)"
    }

    private func terminate(_ request: PortTerminationRequest) {
        let result = monitor.ports.terminate(pid: request.row.pid, force: request.force)
        statusText = "\(request.row.processName): \(result.message)"

        if case .success = result {
            refresh()
        }
    }
}
