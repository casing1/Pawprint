import SwiftUI
import PawprintCore

/// Update checking, and the signature that makes it safe to install what comes back.
@MainActor
struct UpdateSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter
    @Bindable var updater = UpdateChecker.shared

    private var settings: AppSettings { activityCenter.settings }

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.t("settingsRootView.c0a56eea")) {
                    Text("\(updater.currentVersion) (\(updater.currentBuild))")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(L10n.t("settingsRootView.ef2792c1"), isOn: activityCenter.binding(\.updateCheckEnabled))
                Text(L10n.t("settingsRootView.267a3303"))
                    .font(.caption2).foregroundStyle(.secondary)

                if settings.updateCheckEnabled {
                    Toggle(L10n.t("settingsRootView.aa2a685b"), isOn: activityCenter.binding(\.updateCheckAutomatically))
                }
            }

            if settings.updateCheckEnabled {
                Section(L10n.t("settingsRootView.2926977b")) {
                    statusRow
                    HStack {
                        Button(L10n.t("settingsRootView.a8201e37")) {
                            Task { await updater.check(feedURL: settings.updateFeedURL, manual: true) }
                        }
                        .disabled(settings.updateFeedURL.isEmpty || isBusy)
                        if case .available(let release) = updater.state {
                            Button(L10n.t("settingsRootView.5c5095ab")) { Task { await updater.download(release) } }
                                .buttonStyle(.borderedProminent)
                            Button(L10n.t("settingsRootView.7d536052")) { updater.openDownloadPage(release) }
                        }
                        if case .readyToInstall = updater.state {
                            Button(L10n.t("settingsRootView.e723d26a")) { updater.install() }
                                .buttonStyle(.borderedProminent)
                            Button(L10n.t("settingsRootView.19b2d19b")) { updater.dismiss() }
                        }
                        Spacer()
                    }
                }
            }

            Section(L10n.t("settingsRootView.7d793248")) {
                Text(L10n.t("settingsRootView.bf7fbbb3"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var isBusy: Bool {
        switch updater.state {
        case .checking, .downloading: return true
        default: return false
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updater.state {
        case .idle:
            Text(L10n.t("settingsRootView.b0177d91")).font(.caption).foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(L10n.t("settingsRootView.33c1f78f")).font(.caption) }
        case .upToDate(let at):
            Label(L10n.t("settingsRootView.964c983e", at.formatted(date: .omitted, time: .shortened)),
                  systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .available(let release):
            VStack(alignment: .leading, spacing: 3) {
                Label(L10n.t("settingsRootView.dbaf68c1", release.version), systemImage: "sparkles")
                    .font(.callout.weight(.semibold))
                if let notes = release.notes {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("settingsRootView.cc336a93")).font(.caption)
                ProgressView(value: progress)
            }
        case .readyToInstall(let release):
            Label(L10n.t("settingsRootView.64b5f1e0", release.version), systemImage: "checkmark.seal.fill")
                .font(.caption).foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
