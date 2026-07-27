import SwiftUI

/// The month retrospective, presented one reveal at a time.
///
/// Paced deliberately: each slide animates its number in rather than showing everything at once,
/// because the reveal *is* the point. Advancing is manual — an auto-advancing story would rush
/// past the numbers people actually want to sit with.
struct WrappedView: View {
    let report: WrappedReport
    let onClose: () -> Void

    @State private var index = 0
    @State private var revealed = false

    private var slide: WrappedReport.Slide { report.slides[min(index, report.slides.count - 1)] }
    private var isLast: Bool { index >= report.slides.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)

            ZStack {
                slideBody
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                if index == 0 || isLast {
                    ConfettiView(particleCount: 26, duration: 2.0).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .clipped()

            footer
        }
        .frame(width: 360)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.11, blue: 0.19), Color(red: 0.07, green: 0.07, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .onAppear { animateReveal() }
        .onChange(of: index) { _, _ in animateReveal() }
    }

    private func animateReveal() {
        revealed = false
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.08)) { revealed = true }
    }

    private var header: some View {
        HStack {
            Text("🐾 Pawprint Wrapped")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text("\(index + 1) / \(report.slides.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var slideBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !slide.eyebrow.isEmpty {
                Text(slide.eyebrow)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Text(slide.headline)
                .font(.system(size: headlineSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(revealed ? 1 : 0.82, anchor: .leading)
                .opacity(revealed ? 1 : 0)

            content

            if let footnote = slide.footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(revealed ? 1 : 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var headlineSize: CGFloat {
        slide.headline.count > 16 ? 22 : 30
    }

    @ViewBuilder
    private var content: some View {
        switch slide.kind {
        case .opener, .bigNumber, .closer:
            EmptyView()

        case .comparison(let lead, let trail):
            HStack(spacing: 10) {
                pill(lead, tint: .cyan, label: L10n.t("wrappedView.fa72e1d8"))
                pill(trail, tint: .white.opacity(0.35), label: L10n.t("wrappedView.7c7d578d"))
            }
            .opacity(revealed ? 1 : 0)

        case .highlightDay(let day, let detail):
            VStack(alignment: .leading, spacing: 3) {
                if day.count == 10 {
                    Text(Formatters.dayLabel(day))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(revealed ? 1 : 0)

        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { position, item in
                    HStack(spacing: 8) {
                        Text("\(position + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black.opacity(0.7))
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.cyan.opacity(0.85)))
                        Text(item.0).font(.callout.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.1).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
                    }
                    .opacity(revealed ? 1 : 0)
                    .offset(x: revealed ? 0 : 12)
                    .animation(.spring(response: 0.5).delay(Double(position) * 0.08), value: revealed)
                }
            }
        }
    }

    private func pill(_ value: String, tint: Color, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.callout.weight(.bold)).foregroundStyle(tint)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.28)) { index = max(0, index - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(index == 0 ? 0.2 : 0.7))
            .disabled(index == 0)

            // Progress dots double as a sense of "how much is left".
            HStack(spacing: 3) {
                ForEach(0..<report.slides.count, id: \.self) { position in
                    Capsule()
                        .fill(position == index ? Color.cyan : Color.white.opacity(0.22))
                        .frame(width: position == index ? 14 : 5, height: 4)
                }
            }
            .frame(maxWidth: .infinity)

            if isLast {
                ShareButton(
                    mode: .wrapped(report),
                    label: L10n.t("wrappedView.7dedeb82"),
                    suggestedFileName: "pawprint_wrapped_\(report.monthKey).png"
                )
                .fixedSize()
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) { index = min(report.slides.count - 1, index + 1) }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
