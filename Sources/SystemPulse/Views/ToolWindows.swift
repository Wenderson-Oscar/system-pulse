import SwiftUI
import AppKit

/// Lightweight window presenter that opens auxiliary panels (process list, file scanner).
enum ToolWindows {
    private static var processWindow: NSWindow?
    private static var heavyFilesWindow: NSWindow?

    static func showProcesses(monitor: PerformanceMonitor) {
        NSApp.setActivationPolicy(.regular)
        if let w = processWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let content = ProcessListView(monitor: monitor)
        let hosting = NSHostingController(rootView: content)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Processos"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 620, height: 440))
        w.center()
        w.isReleasedWhenClosed = false
        processWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func showHeavyFiles(monitor: PerformanceMonitor) {
        NSApp.setActivationPolicy(.regular)
        if let w = heavyFilesWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let content = HeavyFilesView(monitor: monitor)
        let hosting = NSHostingController(rootView: content)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Arquivos pesados"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 720, height: 480))
        w.center()
        w.isReleasedWhenClosed = false
        heavyFilesWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
