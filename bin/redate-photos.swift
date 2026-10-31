// Copies photos with their capture day moved to another month and day, keeping each one's year, for the App Store
// screenshots (bin/app-store-screenshots.zsh). Times become daytime, 20 minutes apart in the order given, so photos of one
// year keep that order and none crosses into the next day. Every date in the metadata changes (EXIF, TIFF and XMP, which
// Photos reads too). JPEGs are copied as they are; other formats (AVIF, HEIC) become JPEGs, which Photos always imports.
// Usage: swift bin/redate-photos.swift MM-DD OUTPUT_FOLDER PHOTO...
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
	FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
	exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3, arguments[0].count == 5 else { fail("Usage: redate-photos.swift MM-DD OUTPUT_FOLDER PHOTO...") }
let month = arguments[0].prefix(2)
let day = arguments[0].suffix(2)
let output = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
// 2016:06:07 09:30:53 (EXIF, TIFF) or 2016-06-07T09:30:53.959 (XMP)
let datePattern = try Regex(#"(\d{4})([-:])\d{2}[-:]\d{2}([ T])\d{2}:\d{2}(.*)"#, as: (Substring, Substring, Substring, Substring, Substring).self)

for (index, path) in arguments.dropFirst(2).enumerated() {
	let input = URL(fileURLWithPath: path)
	guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), let type = CGImageSourceGetType(source), let original = CGImageSourceCopyMetadataAtIndex(source, 0, nil), let metadata = CGImageMetadataCreateMutableCopy(original) else { fail("Can't read \(path)") }
	let minutes = 9 * 60 + index * 20
	let time = String(format: "%02d:%02d", minutes / 60 % 24, minutes % 60)
	var changes: [(path: String, value: String)] = []
	CGImageMetadataEnumerateTagsUsingBlock(original, nil, [kCGImageMetadataEnumerateRecursively: true] as CFDictionary) { tagPath, tag in
		if let value = CGImageMetadataTagCopyValue(tag) as? String, let match = value.wholeMatch(of: datePattern) {
			let (_, year, separator, timeSeparator, rest) = match.output
			changes.append((tagPath as String, "\(year)\(separator)\(month)\(separator)\(day)\(timeSeparator)\(time)\(rest)"))
		}
		return true
	}
	guard !changes.isEmpty else { fail("No capture date in \(path)") }
	for change in changes {
		CGImageMetadataSetValueWithPath(metadata, nil, change.path as CFString, change.value as CFString)
	}
	let isJPEG = type as String == "public.jpeg"
	let destinationURL = output.appendingPathComponent(input.deletingPathExtension().lastPathComponent).appendingPathExtension(isJPEG ? input.pathExtension : "jpg")
	guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, "public.jpeg" as CFString, 1, nil) else { fail("Can't write \(destinationURL.path)") }
	if isJPEG {
		var error: Unmanaged<CFError>?
		let options = [kCGImageDestinationMetadata: metadata, kCGImageDestinationMergeMetadata: false] as CFDictionary
		guard CGImageDestinationCopyImageSource(destination, source, options, &error) else { fail("Can't write \(destinationURL.path): \(error!.takeRetainedValue())") }
	} else {
		guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("Can't decode \(path)") }
		// The pixels come out upright already, so the orientation tag goes back to normal
		CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFOrientation, 1 as CFNumber)
		CGImageDestinationAddImageAndMetadata(destination, image, metadata, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
		guard CGImageDestinationFinalize(destination) else { fail("Can't write \(destinationURL.path)") }
	}
	print("\(input.lastPathComponent): \(changes.map(\.value).joined(separator: ", "))")
}
