import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: TunnelManager
    var onDismiss: () -> Void = {}

    @State private var maxRetriesText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var configPath: String = ""
    @State private var showRestartHint: Bool = false

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

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("配置文件路径")
                    HStack(spacing: 6) {
                        TextField("默认路径", text: $configPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                        Button("选择...") { chooseConfigPath() }
                            .font(.system(size: 11))
                        if !configPath.isEmpty {
                            Button("重置") {
                                configPath = ""
                                saveConfigPath()
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        }
                    }
                    Text(configPath.isEmpty ? "当前：~/Library/Application Support/Tunnel/config.json" : "当前：\(configPath)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if showRestartHint {
                        Text("路径已更新，重启应用后生效")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
            .font(.system(size: 13))

            Spacer().frame(height: 4)

            Button("完成") {
                applyMaxRetries()
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            maxRetriesText = String(manager.settings.maxRetries)
            launchAtLogin = manager.settings.launchAtLogin
            configPath = ConfigStore.loadPathSettings()?.customConfigPath ?? ""
        }
        .alert("无效的配置文件", isPresented: $showInvalidFileAlert) {
            Button("确定") {}
        } message: {
            Text("所选文件不是有效的 Buu SSH Tunnels 配置文件，请选择其他文件或目录。")
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

    @State private var showInvalidFileAlert: Bool = false

    private func chooseConfigPath() {
        let panel = NSOpenPanel()
        panel.title = "选择配置文件或目录"
        panel.message = "选择已有的配置文件，或选择目录（自动创建 config.json）"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json, .folder]
        if panel.runModal() == .OK, let url = panel.url {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                configPath = url.appendingPathComponent("config.json").path
                saveConfigPath()
            } else {
                // Validate that the file is a valid AppConfig
                if let data = try? Data(contentsOf: url),
                   let _ = try? JSONDecoder().decode(AppConfig.self, from: data) {
                    configPath = url.path
                    saveConfigPath()
                } else {
                    showInvalidFileAlert = true
                }
            }
        }
    }

    private func saveConfigPath() {
        let settings = PathSettings(customConfigPath: configPath.isEmpty ? nil : configPath)
        ConfigStore.savePathSettings(settings)
        showRestartHint = true
    }
}
