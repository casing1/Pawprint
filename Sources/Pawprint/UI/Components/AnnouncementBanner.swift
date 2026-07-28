import SwiftUI

/// The notice strip at the top of the popover, plus the sheet behind it.
///
/// One line and a chevron: a notice is worth interrupting for, but not worth burying today's stats
/// under. The full text lives on the sheet, and the only thing that makes it go away is pressing
/// "don't show again" there — closing the sheet leaves the banner in place.
@MainActor
struct AnnouncementBanner: View {
    @Bindable var center = AnnouncementCenter.shared
    @Bindable var localization = LocalizationManager.shared

    @State private var showingDetail = false

    var body: some View {
        if let announcement = center.current {
            Button {
                showingDetail = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: announcement.isWarning
                          ? "exclamationmark.triangle.fill" : "megaphone.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(announcement.isWarning ? .orange : Color.accentColor)
                    Text(announcement.title(for: localization.languageCode))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(announcement.isWarning
                          ? Color.orange.opacity(0.13) : Color.accentColor.opacity(0.12)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingDetail) {
                AnnouncementDetailView(announcement: announcement) { dismissForever in
                    if dismissForever { center.dismiss(announcement) }
                    showingDetail = false
                }
            }
        }
    }
}

@MainActor
private struct AnnouncementDetailView: View {
    let announcement: Announcement
    /// `true` means "don't show again"; `false` is an ordinary close, which keeps the banner.
    var onClose: (Bool) -> Void

    @Bindable private var localization = LocalizationManager.shared

    /// Parses **bold**, *italic* and links, leaving everything else alone. Whitespace is
    /// preserved so an empty line stays an empty line and paragraphs keep their spacing.
    static func inlineMarkdown(_ line: String) -> AttributedString {
        (try? AttributedString(
            markdown: line,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(line)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: announcement.isWarning
                      ? "exclamationmark.triangle.fill" : "megaphone.fill")
                    .foregroundStyle(announcement.isWarning ? .orange : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(announcement.title(for: localization.languageCode))
                        .font(.headline)
                    if let published = announcement.publishedAt {
                        Text(Formatters.dayLabel(published))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { onClose(false) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
            .padding(14)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // Rendered line by line rather than as one string: notices are written in a
                    // GitHub issue, so the body is markdown. `Text` understands inline markup but
                    // not block structure, so lists and blank lines are kept as literal lines and
                    // only the inline markup is parsed.
                    ForEach(Array(announcement.body(for: localization.languageCode)
                        .components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        Text(Self.inlineMarkdown(line))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .textSelection(.enabled)
                .padding(14)
            }

            Divider()
            HStack(spacing: 8) {
                if let link = announcement.link, let url = URL(string: link) {
                    Button(L10n.t("announcement.open")) { NSWorkspace.shared.open(url) }
                }
                Spacer()
                // The only control that stops the banner coming back.
                Button(L10n.t("announcement.dontShowAgain")) { onClose(true) }
                Button(L10n.t("announcement.close")) { onClose(false) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 420, height: 380)
    }
}
