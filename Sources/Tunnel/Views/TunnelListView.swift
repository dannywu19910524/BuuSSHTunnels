import SwiftUI

struct TunnelListView: View {
    @EnvironmentObject var manager: TunnelManager
    @State private var activeSheet: SheetType?

    enum SheetType: Identifiable {
        case add
        case edit(TunnelConfig)
        case settings

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let t): return t.id.uuidString
            case .settings: return "settings"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tunnel Manager")
                    .font(.headline)
                Spacer()
                Button { activeSheet = .settings } label: {
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
                                activeSheet = .edit(tunnel)
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
                Button { activeSheet = .add } label: {
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
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .add:
                    AddTunnelView()
                case .edit(let tunnel):
                    AddTunnelView(editingTunnel: tunnel)
                case .settings:
                    SettingsView()
                }
            }
            .environmentObject(manager)
        }
    }
}
