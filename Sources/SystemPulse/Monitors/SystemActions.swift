import Foundation

enum SystemActions {
    /// Runs `/usr/sbin/purge` via `osascript` asking for admin privileges.
    /// Returns a human-readable status message.
    static func purgeRAM() -> String {
        let script = """
        do shell script "/usr/sbin/purge" with administrator privileges
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Failed to start: \(error.localizedDescription)"
        }

        if process.terminationStatus == 0 {
            return "Purge completed"
        }
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""
        if errText.contains("User canceled") || errText.contains("-128") {
            return "Cancelled by user"
        }
        return "Failed: \(errText.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}
