import SwiftUI

// One image type for both platforms: Photos hands back UIImage on iPhone and iPad, NSImage on the Mac.

#if canImport(UIKit)
import UIKit

typealias PlatformImage = UIImage

extension Image {
	init(platformImage: PlatformImage) {
		self.init(uiImage: platformImage)
	}
}

extension UIImage {
	nonisolated func jpegData(quality: CGFloat) -> Data? {
		jpegData(compressionQuality: quality)
	}
}
#else
import AppKit

typealias PlatformImage = NSImage

extension Image {
	init(platformImage: PlatformImage) {
		self.init(nsImage: platformImage)
	}
}

extension NSImage {
	nonisolated func jpegData(quality: CGFloat) -> Data? {
		guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
		return NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: quality])
	}
}
#endif
