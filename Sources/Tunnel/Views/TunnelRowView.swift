import SwiftUI

struct TunnelRowView: View {
    let tunnel: TunnelConfig
    let onEdit: () -> Void
    @EnvironmentObject var manager: TunnelManager
    @State private var showLogs = false
    @State private var showDeleteAlert = false

    private var state: TunnelState {
        manager.tunnelStates[tunnel.id] ?? TunnelState()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.name.isEmpty ? "Untitled" : tunnel.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(tunnel.command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if state.retryCount > 0 && state.status.isActive {
                        Text("重连 \(state.retryCount)")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    Text(statusText)
                        .font(.system(size: 9))
                        .foregroundColor(statusColor)
                }

                Toggle("", isOn: Binding(
                    get: { state.status.isActive },
                    set: { newValue in
                        if newValue {
                            manager.startTunnel(id: tunnel.id)
                        } else {
                            manager.stopTunnel(id: tunnel.id)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            if (showLogs || state.status.isFailed) && !state.recentLogs.isEmpty {
                ScrollView {
                    Text(state.recentLogs.joined(separator: "\n"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 80)
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .onTapGesture { showLogs.toggle() }
        .contextMenu {
            Button("编辑") { onEdit() }
            Button("复制") {
                let copy = TunnelConfig(
                    name: (tunnel.name.isEmpty ? "Untitled" : tunnel.name) + " 副本",
                    command: tunnel.command,
                    autoConnect: false,
                    tag: tunnel.tag,
                    autoKillPortConflicts: tunnel.autoKillPortConflicts
                )
                manager.addTunnel(copy)
            }
            Divider()
            Button("删除", role: .destructive) { showDeleteAlert = true }
        }
        .alert("确定删除?", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { manager.removeTunnel(id: tunnel.id) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 \"\(tunnel.name.isEmpty ? "Untitled" : tunnel.name)\"")
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .reconnecting: return .orange
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch state.status {
        case .disconnected: return "已断开"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .reconnecting: return "重连中..."
        case .failed(let reason): return reason
        }
    }

    private var borderColor: Color {
        switch state.status {
        case .failed: return .red.opacity(0.3)
        case .reconnecting: return .orange.opacity(0.3)
        default: return Color(nsColor: .separatorColor)
        }
    }
}
