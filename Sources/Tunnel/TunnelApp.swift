import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let manager = TunnelManager()
    private var iconCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Buu SSH Tunnels")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let contentView = TunnelListView()
            .environmentObject(manager)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        // Update menubar icon when tunnel states change
        iconCancellable = manager.$tunnelStates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Keep popover focused
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon() {
        let iconName = manager.menuBarIcon
        statusItem.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "Buu SSH Tunnels"
        )
    }
}

@main
struct TunnelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
