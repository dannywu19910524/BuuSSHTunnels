import SwiftUI

struct TunnelFormView: View {
    @Binding var formData: TunnelFormData

    var body: some View {
        VStack(spacing: 14) {
            connectionSection
            forwardSection
        }
    }

    // MARK: - SSH Connection Section

    private var connectionSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("用户")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("登录名", text: $formData.user)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    .frame(width: 100)

                    Text("@")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("主机")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("IP 地址或主机名", text: $formData.host)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("端口")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("22", value: $formData.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .frame(width: 55)
                    }
                }
            }
        } label: {
            Text("SSH 连接")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
                .textCase(.uppercase)
        }
    }

    // MARK: - Port Forwarding Section

    private var forwardSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                ForEach($formData.forwards) { $fwd in
                    forwardRow(fwd: $fwd)
                }
                HStack {
                    Button {
                        formData.forwards.append(PortForward())
                    } label: {
                        Label("添加规则", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    Spacer()

                    legendView
                }
            }
        } label: {
            HStack {
                Text("端口转发")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .textCase(.uppercase)
                Spacer()
            }
        }
    }

    private func forwardRow(fwd: Binding<PortForward>) -> some View {
        HStack(spacing: 6) {
            Picker("", selection: fwd.type) {
                ForEach(ForwardType.allCases, id: \.self) { type in
                    Text(type == .local ? "本地" : "远程").tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 60)
            .font(.system(size: 11))

            // Bind side (green)
            HStack(spacing: 2) {
                TextField("地址", text: fwd.bindAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 60)
                Text(":")
                    .foregroundColor(.secondary)
                TextField("端口", text: fwd.bindPort)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 50)
            }
            .padding(4)
            .background(Color.green.opacity(0.1))
            .cornerRadius(6)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Dest side (blue)
            HStack(spacing: 2) {
                TextField("目标地址", text: fwd.destHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 80)
                Text(":")
                    .foregroundColor(.secondary)
                TextField("端口", text: fwd.destPort)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 50)
            }
            .padding(4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)

            if formData.forwards.count > 1 {
                Button {
                    formData.forwards.removeAll { $0.id == fwd.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var legendView: some View {
        HStack(spacing: 10) {
            legendDot(color: .green, label: "本机")
            legendDot(color: .orange, label: "远程主机")
            legendDot(color: .blue, label: "目标主机")
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }
}
