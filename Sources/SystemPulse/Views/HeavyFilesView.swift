import SwiftUI
import AppKit

struct HeavyFilesView: View {
    @ObservedObject var monitor: PerformanceMonitor
    @State private var files: [HeavyFile] = []
    @State private var scanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Arquivos pesados")
                    .font(.headline)
                Spacer()
                Button(scanning ? "Escaneando…" : "Escanear agora") { scan() }
                    .disabled(scanning)
            }
            Text("Pastas: Downloads, Desktop, Documents, Movies")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Table(files) {
                TableColumn("Arquivo") { f in
                    Text(f.url.lastPathComponent).lineLimit(1)
                }
                TableColumn("Caminho") { f in
                    Text(f.url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                TableColumn("Tamanho") { f in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(f.sizeBytes), countStyle: .file))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(100)
                TableColumn("") { f in
                    Button("Revelar") {
                        NSWorkspace.shared.activateFileViewerSelecting([f.url])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .width(80)
            }
            .frame(minHeight: 320)
        }
        .padding(14)
        .frame(width: 720, height: 480)
    }

    private func scan() {
        scanning = true
        Task {
            let result = await monitor.fileScanner.scan(
                directories: FileScanner.defaultDirectories(),
                limit: 25
            )
            await MainActor.run {
                self.files = result
                self.scanning = false
            }
        }
    }
}
