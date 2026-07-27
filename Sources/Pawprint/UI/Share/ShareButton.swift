import SwiftUI

/// Share control with a preview + copy/save actions. Shows inline confirmation after copying
/// so the user knows the image is on the clipboard without leaving the popover.
@MainActor
struct ShareButton: View {
    let mode: ShareCardView.Mode
    let label: String
    let suggestedFileName: String

    @Bindable private var activityCenter = ActivityCenter.shared
    private var metrics: [MetricDefinition] {
        MetricCatalog.shareMetrics(settings: activityCenter.settings)
    }

    @State private var showingPreview = false
    @State private var statusMessage: String?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showingPreview = true
            } label: {
                Label(label, systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                copy()
            } label: {
                Label(L10n.t("shareButton.133105d3"), systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .popover(isPresented: $showingPreview, arrowEdge: .bottom) {
            SharePreview(mode: mode, metrics: metrics, suggestedFileName: suggestedFileName)
        }
    }

    private func copy() {
        let result = ShareCardRenderer.copyToPasteboard(mode, metrics: metrics)
        withAnimation {
            switch result {
            case .copied: statusMessage = L10n.t("shareButton.91de2617")
            case .failed(let message): statusMessage = message
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { statusMessage = nil }
        }
    }
}

@MainActor
private struct SharePreview: View {
    let mode: ShareCardView.Mode
    let metrics: [MetricDefinition]
    let suggestedFileName: String

    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                ShareCardView(mode: mode, metrics: metrics)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(8)
            }
            .frame(maxHeight: 420)

            HStack(spacing: 8) {
                Button {
                    apply(ShareCardRenderer.copyToPasteboard(mode, metrics: metrics), success: L10n.t("shareButton.8a7e1e6b"))
                } label: {
                    Label(L10n.t("shareButton.86d50d54"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    apply(ShareCardRenderer.saveToFile(mode, metrics: metrics, suggestedName: suggestedFileName), success: L10n.t("shareButton.9a5d1478"))
                } label: {
                    Label(L10n.t("shareButton.8f23fa96"), systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
            }

            if let statusMessage {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(L10n.t("shareButton.24691176"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(width: ShareCardView.cardWidth + 40)
    }

    private func apply(_ result: ShareCardRenderer.Result, success: String) {
        switch result {
        case .copied: statusMessage = success
        case .failed(let message): statusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            statusMessage = nil
        }
    }
}
