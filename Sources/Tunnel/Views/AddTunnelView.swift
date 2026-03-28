import SwiftUI

enum InputMode: String, CaseIterable {
    case form = "表单模式"
    case command = "命令模式"
}

struct AddTunnelView: View {
    @EnvironmentObject var manager: TunnelManager

    var editingTunnel: TunnelConfig?
    var onDismiss: () -> Void = {}

    @State private var name: String = ""
    @State private var tag: String = ""
    @State private var command: String = ""
    @State private var autoConnect: Bool = true
    @State private var autoKillPortConflicts: Bool = false
    @State private var mode: InputMode = .form
    @State private var formData = TunnelFormData()
    @State private var showParseError: Bool = false

    private var isEditing: Bool { editingTunnel != nil }

    private var isValid: Bool {
        switch mode {
        case .form:
            let hostOk = !formData.host.trimmingCharacters(in: .whitespaces).isEmpty
            let userOk = !formData.user.trimmingCharacters(in: .whitespaces).isEmpty
            let forwardOk = formData.forwards.contains {
                !$0.bindPort.trimmingCharacters(in: .whitespaces).isEmpty &&
                !$0.destPort.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return hostOk && userOk && forwardOk
        case .command:
            return !command.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "编辑连接" : "新建连接")
                .font(.headline)

            // Name + Tag row
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("名称")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("例如: 生产数据库", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("标签")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("例如: production", text: $tag)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }

            // Mode content
            if mode == .form {
                TunnelFormView(formData: $formData)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SSH 命令")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("ssh -L 3306:localhost:3306 user@server", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }
            }

            Toggle("启动时自动连接", isOn: $autoConnect)
                .font(.system(size: 13))

            Toggle("自动关闭占用端口的进程", isOn: $autoKillPortConflicts)
                .font(.system(size: 13))

            // Mode toggle + action buttons
            HStack {
                Picker("", selection: $mode) {
                    ForEach(InputMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: mode) { newMode in
                    handleModeSwitch(to: newMode)
                }

                Spacer()

                Button("取消") { onDismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? "保存" : "添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { loadEditingTunnel() }
        .alert("无法切换到表单模式", isPresented: $showParseError) {
            Button("确定") { mode = .command }
        } message: {
            Text("此命令包含表单不支持的参数，请使用命令模式编辑。")
        }
    }

    private func loadEditingTunnel() {
        guard let tunnel = editingTunnel else { return }
        name = tunnel.name
        tag = tunnel.tag ?? ""
        command = tunnel.command
        autoConnect = tunnel.autoConnect
        autoKillPortConflicts = tunnel.autoKillPortConflicts
        if let parsed = TunnelFormData(fromCommand: tunnel.command) {
            formData = parsed
            mode = .form
        } else {
            mode = .command
        }
    }

    private func handleModeSwitch(to newMode: InputMode) {
        if newMode == .form {
            if let parsed = TunnelFormData(fromCommand: command) {
                formData = parsed
            } else if !command.trimmingCharacters(in: .whitespaces).isEmpty {
                showParseError = true
            }
        } else {
            command = formData.toCommand()
        }
    }

    private func save() {
        let finalCommand: String
        switch mode {
        case .form:
            finalCommand = formData.toCommand()
        case .command:
            finalCommand = command.trimmingCharacters(in: .whitespaces)
        }

        let trimmedTag: String? = tag.trimmingCharacters(in: .whitespaces).isEmpty ? nil : tag.trimmingCharacters(in: .whitespaces)

        if var tunnel = editingTunnel {
            tunnel.name = name
            tunnel.command = finalCommand
            tunnel.autoConnect = autoConnect
            tunnel.tag = trimmedTag
            tunnel.autoKillPortConflicts = autoKillPortConflicts
            manager.updateTunnel(tunnel)
        } else {
            let tunnel = TunnelConfig(
                name: name,
                command: finalCommand,
                autoConnect: autoConnect,
                tag: trimmedTag,
                autoKillPortConflicts: autoKillPortConflicts
            )
            manager.addTunnel(tunnel)
        }
        onDismiss()
    }
}
