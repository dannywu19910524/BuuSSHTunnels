import SwiftUI

struct TunnelListView: View {
    @EnvironmentObject var manager: TunnelManager
    @State private var activeView: ActiveView = .list

    enum ActiveView {
        case list
        case add
        case edit(TunnelConfig)
        case settings
    }

    var body: some View {
        Group {
            switch activeView {
            case .list:
                listContent
            case .add:
                AddTunnelView(onDismiss: { activeView = .list })
            case .edit(let tunnel):
                AddTunnelView(editingTunnel: tunnel, onDismiss: { activeView = .list })
            case .settings:
                SettingsView(onDismiss: { activeView = .list })
            }
        }
        .environmentObject(manager)
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Buu SSH Tunnels")
                    .font(.headline)
                Spacer()
                Button { activeView = .settings } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if manager.tunnels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("没有配置的连接")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.tunnels) { tunnel in
                            TunnelRowView(tunnel: tunnel, onEdit: {
                                activeView = .edit(tunnel)
                            })
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 350)
            }

            Divider()

            HStack {
                Button { activeView = .add } label: {
                    Label("新建连接", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button {
                    NSWorkspace.shared.open(FileLogger.shared.logFileURL)
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("打开日志文件")

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
        .alert("端口被占用", isPresented: Binding(
            get: { manager.portConflict != nil },
            set: { if !$0 { manager.cancelPortConflict() } }
        )) {
            Button("终止进程并连接", role: .destructive) {
                if let conflict = manager.portConflict {
                    manager.forceStartTunnel(killingConflicts: conflict)
                }
            }
            Button("取消", role: .cancel) {
                manager.cancelPortConflict()
            }
        } message: {
            if let conflict = manager.portConflict {
                let details = conflict.ports.map { "端口 \($0.port) → PID \($0.pid) (\($0.processName))" }.joined(separator: "\n")
                Text("以下端口已被其他进程占用：\n\(details)\n\n是否终止这些进程？")
            }
        }
    }
}
