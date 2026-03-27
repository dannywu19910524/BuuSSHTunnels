import SwiftUI

@main
struct TunnelApp: App {
    var body: some Scene {
        MenuBarExtra("Tunnel", systemImage: "network") {
            Text("Hello Tunnel")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
