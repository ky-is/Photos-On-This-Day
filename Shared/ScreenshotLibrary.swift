#if DEBUG && os(macOS)
import AppKit
import CoreLocation
import ImageIO
import Photos

/// Mac App Store screenshots (bin/mac-screenshots.zsh): a Mac app can only read the Mac's own library, so with
/// `-screenshotPhotos <URL>` the app shows the screenshot photos instead, the same ones the iOS screenshots use, redated to
/// the screenshot day. The script serves them on localhost, listed in order in index.txt, since it can't put files in the
/// app's sandbox; the app downloads them into its caches at launch. Debug Mac builds only.
nonisolated enum ScreenshotLibrary {
	private static let server = UserDefaults.standard.string(forKey: "screenshotPhotos").flatMap(URL.init(string:))
	static var isActive: Bool { server != nil }

	static let assets: [ScreenshotAsset] = {
		guard let server, let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first, let index = try? String(contentsOf: server.appendingPathComponent("index.txt"), encoding: .utf8) else { return [] }
		let folder = caches.appendingPathComponent("ScreenshotPhotos")
		try? FileManager.default.removeItem(at: folder)
		try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		return index.split(separator: "\n").enumerated().compactMap { offset, name in
			let file = folder.appendingPathComponent(String(format: "%02d-%@", offset, String(name)))
			guard let data = try? Data(contentsOf: server.appendingPathComponent(String(name))), (try? data.write(to: file)) != nil else { return nil }
			return ScreenshotAsset(url: file)
		}
	}()

	/// Like `PHAsset.assetsByYearsBack`: the photos on `date`'s day in each of those years back
	static func assetsByYearsBack(_ yearsBack: [Int], from date: Date) -> [Int: [PHAsset]] {
		Dictionary(grouping: assets.filter { $0.date.dateID == date.dateID && yearsBack.contains(date.year - $0.date.year) }) { date.year - $0.date.year }
			.mapValues { $0.sorted { $0.date < $1.date } }
	}
}

/// One screenshot photo, standing in for a library photo: its date, size and place come from the file's metadata.
nonisolated final class ScreenshotAsset: PHAsset, @unchecked Sendable {
	let url: URL
	let date: Date
	private let width: Int
	private let height: Int
	private let place: CLLocation?

	init?(url: URL) {
		guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any], let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int, let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any], let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
		guard let date = formatter.date(from: taken) else { return nil }
		self.url = url
		self.date = date
		self.width = width
		self.height = height
		if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any], let latitude = gps[kCGImagePropertyGPSLatitude] as? Double, let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {
			let north = (gps[kCGImagePropertyGPSLatitudeRef] as? String) != "S"
			let east = (gps[kCGImagePropertyGPSLongitudeRef] as? String) != "W"
			place = CLLocation(latitude: north ? latitude : -latitude, longitude: east ? longitude : -longitude)
		} else {
			place = nil
		}
		super.init()
	}

	override var localIdentifier: String { "screenshot/\(url.lastPathComponent)" }
	override var creationDate: Date? { date }
	override var pixelWidth: Int { width }
	override var pixelHeight: Int { height }
	override var location: CLLocation? { place }
	override var mediaType: PHAssetMediaType { .image }
	override var mediaSubtypes: PHAssetMediaSubtype { [] }
	override var isFavorite: Bool { false }
	override var isHidden: Bool { false }
	override var duration: TimeInterval { 0 }
	override var sourceType: PHAssetSourceType { .typeUserLibrary }
	override var burstIdentifier: String? { nil }

	/// The photo at most `size` pixels on its longer side, filling `size` when cropped
	func image(size: CGSize, cropped: Bool) -> PlatformImage? {
		guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
		let aspect = Double(width) / Double(height)
		let fit = cropped ? max(size.width, size.height * aspect) : max(size.width, size.height)
		let longest = cropped && aspect < 1 ? fit / aspect : fit
		let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(Int(longest), 64)] as CFDictionary
		guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
		return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
	}
}
#endif
