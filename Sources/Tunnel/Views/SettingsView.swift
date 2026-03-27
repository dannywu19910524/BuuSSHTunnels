import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: TunnelManager
    @Environment(\.dismiss) var dismiss

    @State private var maxRetriesText: String = ""
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("设置")
                .font(.headline)

            VStack(spacing: 12) {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        var s = manager.settings
                        s.launchAtLogin = newValue
                        manager.updateSettings(s)
                        LoginItemManager.setEnabled(newValue)
                    }

                HStack {
                    Text("最大重连次数")
                    Spacer()
                    TextField("999", text: $maxRetriesText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { applyMaxRetries() }
                }
            }
            .font(.system(size: 13))

            Spacer().frame(height: 4)

            Button("完成") {
                applyMaxRetries()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            maxRetriesText = String(manager.settings.maxRetries)
            launchAtLogin = manager.settings.launchAtLogin
        }
    }

    private func applyMaxRetries() {
        guard let value = Int(maxRetriesText), value > 0 else {
            maxRetriesText = String(manager.settings.maxRetries)
            return
        }
        var s = manager.settings
        s.maxRetries = value
        manager.updateSettings(s)
    }
}
