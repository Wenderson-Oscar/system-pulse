import Foundation
import Darwin

struct OpenPortRow: Identifiable, Hashable {
    var pid: pid_t
    var processName: String
    var user: String
    var protocolName: String
    var localAddress: String
    var port: Int
    var state: String
    var fileDescriptors: [String]
    var processPath: String

    var id: String {
        "\(protocolName)-\(port)-\(pid)-\(localAddress)-\(state)"
    }

    var endpoint: String {
        "\(localAddress):\(port)"
    }

    var fileDescriptorSummary: String {
        fileDescriptors.joined(separator: ", ")
    }
}

struct PortScanResult {
    var rows: [OpenPortRow]
    var warning: String?
}

enum PortTerminationResult {
    case success
    case failure(String)

    var message: String {
        switch self {
        case .success:
            return "Signal sent"
        case .failure(let detail):
            return detail
        }
    }
}

final class PortMonitor {
    func openPorts(includeUDP: Bool = true) -> PortScanResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")

        var arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
        if includeUDP {
            arguments.append("-iUDP")
        }
        arguments.append(contentsOf: ["-F", "pcLfnPT"])
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rows = parseLsofOutput(output)

            if process.terminationStatus != 0, rows.isEmpty {
                let message = error.isEmpty ? "lsof exited with status \(process.terminationStatus)" : error
                return PortScanResult(rows: [], warning: message)
            }

            return PortScanResult(rows: rows, warning: error.isEmpty ? nil : error)
        } catch {
            return PortScanResult(rows: [], warning: "Failed to run lsof: \(error.localizedDescription)")
        }
    }

    func terminate(pid: pid_t, force: Bool = false) -> PortTerminationResult {
        guard pid > 1 else {
            return .failure("Refusing to terminate system PID \(pid)")
        }

        if pid == ProcessInfo.processInfo.processIdentifier {
            return .failure("Refusing to terminate SystemPulse")
        }

        if Darwin.kill(pid, force ? SIGKILL : SIGTERM) == 0 {
            return .success
        }

        return .failure(String(cString: strerror(errno)))
    }

    private func parseLsofOutput(_ output: String) -> [OpenPortRow] {
        var currentPID: pid_t?
        var currentCommand = ""
        var currentUser = ""
        var currentFD = ""
        var currentProtocol = ""
        var currentName = ""
        var currentState = ""
        var pathCache: [pid_t: String] = [:]
        var rowsByKey: [String: OpenPortRow] = [:]

        func resetFile() {
            currentFD = ""
            currentProtocol = ""
            currentName = ""
            currentState = ""
        }

        func path(for pid: pid_t) -> String {
            if let cached = pathCache[pid] {
                return cached
            }
            let resolved = Self.processPath(pid: pid)
            pathCache[pid] = resolved
            return resolved
        }

        func finishFile() {
            guard let pid = currentPID, !currentFD.isEmpty else { return }
            guard let endpoint = Self.parseEndpoint(currentName) else { return }

            let protocolName = currentProtocol.uppercased()
            guard protocolName == "TCP" || protocolName == "UDP" else { return }
            if protocolName == "TCP", currentState != "LISTEN" {
                return
            }

            let resolvedPath = path(for: pid)
            let displayName = Self.processName(pid: pid, fallback: currentCommand, path: resolvedPath)
            let state = currentState.isEmpty ? "OPEN" : currentState
            let key = "\(protocolName)|\(endpoint.port)|\(pid)|\(endpoint.address)|\(state)"

            if var existing = rowsByKey[key] {
                if !existing.fileDescriptors.contains(currentFD) {
                    existing.fileDescriptors.append(currentFD)
                }
                rowsByKey[key] = existing
                return
            }

            rowsByKey[key] = OpenPortRow(
                pid: pid,
                processName: displayName,
                user: currentUser,
                protocolName: protocolName,
                localAddress: endpoint.address,
                port: endpoint.port,
                state: state,
                fileDescriptors: [currentFD],
                processPath: resolvedPath
            )
        }

        for line in output.split(whereSeparator: \.isNewline) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                finishFile()
                currentPID = pid_t(value) ?? 0
                currentCommand = ""
                currentUser = ""
                resetFile()
            case "c":
                currentCommand = value
            case "L":
                currentUser = value
            case "f":
                finishFile()
                resetFile()
                currentFD = value
            case "P":
                currentProtocol = value
            case "n":
                currentName = value
            case "T":
                if value.hasPrefix("ST=") {
                    currentState = String(value.dropFirst(3))
                }
            default:
                continue
            }
        }

        finishFile()

        return rowsByKey.values
            .map { row in
                var copy = row
                copy.fileDescriptors.sort()
                return copy
            }
            .sorted { lhs, rhs in
                if lhs.port != rhs.port {
                    return lhs.port < rhs.port
                }
                if lhs.protocolName != rhs.protocolName {
                    return lhs.protocolName < rhs.protocolName
                }
                let nameCompare = lhs.processName.localizedCaseInsensitiveCompare(rhs.processName)
                if nameCompare != .orderedSame {
                    return nameCompare == .orderedAscending
                }
                return lhs.pid < rhs.pid
            }
    }

    private static func parseEndpoint(_ rawName: String) -> (address: String, port: Int)? {
        var endpoint = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let space = endpoint.firstIndex(of: " ") {
            endpoint = String(endpoint[..<space])
        }
        if let connection = endpoint.range(of: "->") {
            endpoint = String(endpoint[..<connection.lowerBound])
        }

        guard let colon = endpoint.lastIndex(of: ":") else { return nil }
        let portStart = endpoint.index(after: colon)
        guard portStart < endpoint.endIndex else { return nil }

        let portText = String(endpoint[portStart...])
        guard let port = Int(portText) else { return nil }

        let address = String(endpoint[..<colon])
        return (address.isEmpty ? "*" : address, port)
    }

    private static func processName(pid: pid_t, fallback: String, path: String) -> String {
        if !path.isEmpty {
            return URL(fileURLWithPath: path).lastPathComponent
        }

        var buffer = [CChar](repeating: 0, count: 1024)
        let size = proc_name(pid, &buffer, UInt32(buffer.count))
        if size > 0 {
            return String(cString: buffer)
        }

        if !fallback.isEmpty {
            return fallback
        }

        return "pid \(pid)"
    }

    private static func processPath(pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 4096)
        let size = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard size > 0 else { return "" }
        return String(cString: buffer)
    }
}
