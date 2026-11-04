import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("Hop")
                .font(.title2.bold())
            VersionLabel()
        }
        .padding(32)
        .frame(width: 320)
    }
}

private struct VersionLabel: View {
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        Text("Version \(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))")
            .foregroundStyle(.secondary)
    }
}
