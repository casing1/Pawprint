import AppKit
import SwiftUI

/// Renders `ShareCardView` to a bitmap and puts it on the pasteboard, so the user can paste the
/// card straight into a message, doc, or post.
@MainActor
enum ShareCardRenderer {

    enum Result {
        case copied
        case failed(String)
    }

    /// Renders at 2x so the image stays crisp when pasted somewhere that displays it large.
    private static let scale: CGFloat = 2

    static func image(for mode: ShareCardView.Mode, metrics: [MetricDefinition]) -> NSImage? {
        let renderer = ImageRenderer(content: ShareCardView(mode: mode, metrics: metrics))
        renderer.scale = scale
        // ImageRenderer inherits the environment's color scheme; the card is designed dark-only.
        return renderer.nsImage
    }

    @discardableResult
    static func copyToPasteboard(_ mode: ShareCardView.Mode, metrics: [MetricDefinition]) -> Result {
        guard let image = image(for: mode, metrics: metrics) else {
            return .failed("이미지를 만들지 못했어요")
        }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return .failed("이미지를 변환하지 못했어요")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // Write both PNG and the NSImage: some targets prefer one over the other.
        pasteboard.setData(png, forType: .png)
        pasteboard.writeObjects([image])
        return .copied
    }

    /// Saves the card to a file the user picks. Offered alongside copying because some apps
    /// only accept file attachments.
    @discardableResult
    static func saveToFile(_ mode: ShareCardView.Mode, metrics: [MetricDefinition], suggestedName: String) -> Result {
        guard let image = image(for: mode, metrics: metrics),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return .failed("이미지를 만들지 못했어요")
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else {
            return .failed("저장을 취소했어요")
        }
        do {
            try png.write(to: url)
            return .copied
        } catch {
            return .failed("저장하지 못했어요: \(error.localizedDescription)")
        }
    }
}
