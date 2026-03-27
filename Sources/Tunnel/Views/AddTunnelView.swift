import SwiftUI

struct AddTunnelView: View {
    @EnvironmentObject var manager: TunnelManager
    @Environment(\.dismiss) var dismiss

    var editingTunnel: TunnelConfig?

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var autoConnect: Bool = true

    private var isEditing: Bool { editingTunnel != nil }
    private var isValid: Bool { !command.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "编辑连接" : "新建连接")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("名称")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("例如: 生产数据库", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SSH 命令")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("ssh -L 3306:localhost:3306 user@server", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            Toggle("启动时自动连接", isOn: $autoConnect)
                .font(.system(size: 13))

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "保存" : "添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if let tunnel = editingTunnel {
                name = tunnel.name
                command = tunnel.command
                autoConnect = tunnel.autoConnect
            }
        }
    }

    private func save() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        if var tunnel = editingTunnel {
            tunnel.name = name
            tunnel.command = trimmedCommand
            tunnel.autoConnect = autoConnect
            manager.updateTunnel(tunnel)
        } else {
            let tunnel = TunnelConfig(
                name: name,
                command: trimmedCommand,
                autoConnect: autoConnect
            )
            manager.addTunnel(tunnel)
        }
        dismiss()
    }
}
