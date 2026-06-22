import SwiftUI

struct PermissionDoctorView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permission Doctor")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Cordierite needs the following permissions to capture speech, listen for hotkeys, and paste text.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !appModel.setupIssues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appModel.setupIssues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.message)
                                    .fontWeight(.medium)
                                Text(issue.guidance)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }

            List {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionRow(
                        kind: kind,
                        status: appModel.permissionStatuses[kind] ?? .unknown,
                        onOpenSettings: { appModel.openPermissionSettings(for: kind) },
                        onRequestAccess: { appModel.requestPermission(for: kind) }
                    )
                }
            }
            .listStyle(.inset)

            HStack {
                Button("Recheck") {
                    appModel.refreshPermissionState()
                }

                Spacer()

                footerStatusLabel
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 400)
    }

    @ViewBuilder
    private var footerStatusLabel: some View {
        switch appModel.state {
        case .loading:
            Label("Checking permissions…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .recording, .processing:
            Label("Finish current activity to update setup state", systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .needsSetup:
            Label("Setup incomplete", systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
                .font(.caption)
        case .ready:
            if appModel.allPermissionsGranted {
                Label("All permissions granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("Setup incomplete", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }
}

private struct PermissionRow: View {
    let kind: PermissionKind
    let status: PermissionStatus
    let onOpenSettings: () -> Void
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kind.title)
                    .fontWeight(.medium)
                Spacer()
                Text(status.label)
                    .foregroundStyle(statusColor)
            }

            Text(kind.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if showsRequestButton {
                    Button("Request Access") {
                        onRequestAccess()
                    }
                }

                Button("Open System Settings") {
                    onOpenSettings()
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var showsRequestButton: Bool {
        switch kind {
        case .microphone:
            status == .notDetermined
        case .inputMonitoring:
            status == .notDetermined
        case .accessibility:
            !status.isGranted
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:
            .green
        case .denied:
            .red
        case .notDetermined:
            .orange
        case .unknown:
            .secondary
        }
    }
}

#Preview {
    PermissionDoctorView()
        .environment(AppModel())
}
