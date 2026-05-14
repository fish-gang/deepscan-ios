import UIKit

enum ImageCrop {

    // Crops a UIImage to a normalized box (top-left origin, 0...1) and adds
    // padding around the box before cropping. Padding gives the classifier
    // some surrounding water/reef context — tight crops noticeably hurt
    // confidence because the model was trained on whole-fish photos with
    // background, not on isolated cutouts.
    //
    // Returns nil only on truly degenerate input (zero-size image / box).
    static func crop(
        _ image: UIImage,
        to normalizedBox: CGRect,
        padding: CGFloat = 0.15
    ) -> UIImage? {

        let size = image.size
        guard size.width > 0, size.height > 0,
              normalizedBox.width > 0, normalizedBox.height > 0 else {
            return nil
        }

        // Expand by `padding` on each side, clamped to the image.
        let padX = normalizedBox.width * padding
        let padY = normalizedBox.height * padding
        let padded = CGRect(
            x: max(0, normalizedBox.minX - padX),
            y: max(0, normalizedBox.minY - padY),
            width: min(1 - max(0, normalizedBox.minX - padX),
                       normalizedBox.width + 2 * padX),
            height: min(1 - max(0, normalizedBox.minY - padY),
                        normalizedBox.height + 2 * padY)
        )

        let pixelRect = CGRect(
            x: padded.minX * size.width,
            y: padded.minY * size.height,
            width: padded.width * size.width,
            height: padded.height * size.height
        )

        // UIGraphicsImageRenderer handles imageOrientation correctly via
        // UIImage.draw(at:), so we work in `image.size` (orientation-aware)
        // space throughout — no manual CGImage transform needed.
        let renderer = UIGraphicsImageRenderer(size: pixelRect.size)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -pixelRect.minX, y: -pixelRect.minY))
        }
    }
}
