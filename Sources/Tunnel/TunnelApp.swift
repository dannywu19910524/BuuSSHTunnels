import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct TunnelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var manager = TunnelManager()

    var body: some Scene {
        MenuBarExtra {
            TunnelListView()
                .environmentObject(manager)
        } label: {
            Image(systemName: manager.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
