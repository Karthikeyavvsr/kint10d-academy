import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Fixed atlas: 4 columns × 3 rows. Frames are cropped once, never on each animation tick.
enum MikoAtlas {
    static let frames: [Image] = {
        guard let url = Bundle.main.url(forResource: "MikoAtlas", withExtension: "png") else { return [] }
        #if os(iOS)
        guard let source = UIImage(contentsOfFile: url.path)?.cgImage else { return [] }
        #else
        guard let source = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        #endif
        return (0..<12).compactMap { index in
            let width = source.width / 4, height = source.height / 3
            guard let crop = source.cropping(to: CGRect(x: (index % 4) * width, y: (index / 4) * height, width: width, height: height)) else { return nil }
            // ActivityKit validates intrinsic image size, not just the SwiftUI frame.
            // 72px at 3× is a 24pt portrait even in the minimal Island layout.
            guard let bitmap = CGContext(data: nil, width: 72, height: 72, bitsPerComponent: 8,
                                         bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            bitmap.interpolationQuality = .high
            bitmap.draw(crop, in: CGRect(x: 0, y: 0, width: 72, height: 72))
            guard let thumbnail = bitmap.makeImage() else { return nil }
            return Image(decorative: thumbnail, scale: 3)
        }
    }()
}

struct MikoSprite: View {
    var frame: Int
    var body: some View {
        Group {
            if MikoAtlas.frames.indices.contains(frame) {
                MikoAtlas.frames[frame].resizable().scaledToFit()
            } else {
                Image(systemName: "pawprint.fill").resizable().scaledToFit().foregroundStyle(.gray)
            }
        }.accessibilityHidden(true)
    }
}
