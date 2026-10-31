import AVFoundation
import CoreGraphics
import SwiftUI

/// Writes a slideshow video: a fixed backdrop (the story's header) with photos crossfading one after another in a rounded frame, each slowly zooming in.
nonisolated enum CollageVideo {
	struct Slide: @unchecked Sendable {
		let image: CGImage
		/// The part to keep in view, from 0 to 1 with the origin at the top left.
		let focus: UnitPoint
		let year: Int
		/// The year, drawn in the photo's corner.
		let label: CGImage?
	}

	static let slideSeconds = 2.6
	static let fadeSeconds = 0.6
	/// The last photo stays a moment longer before the video loops.
	static let endSeconds = 0.8
	static let framesPerSecond: Int32 = 30
	/// How much each photo grows while it's on screen.
	static let zoom = 0.08

	/// `photoArea` is in the backdrop's pixels, with the origin at the top left. `progress` gets the share of frames written so far, from 0 to 1.
	@concurrent static func make(backdrop: CGImage, photoArea: CGRect, cornerRadius: CGFloat, slides: [Slide], to url: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
		let width = backdrop.width
		let height = backdrop.height
		try? FileManager.default.removeItem(at: url)
		let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
		let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height, AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000]])
		let attributes = CVPixelBufferCreationAttributes(pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height), compatibility: [.cgBitmapContext])
		let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
		try writer.start()
		writer.startSession(atSourceTime: .zero)
		let frameCount = Int((Double(slides.count) * slideSeconds + endSeconds) * Double(framesPerSecond))
		let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
		// In the frames' own pixel format, so drawing them each frame is a plain copy, not a conversion.
		let backdrop = matching(backdrop, colorSpace: colorSpace)
		let slides = slides.map { Slide(image: matching($0.image, colorSpace: colorSpace), focus: $0.focus, year: $0.year, label: $0.label) }
		// Frames are drawn a batch at a time across the cores, then handed to the encoder in order.
		let batchSize = min(8, max(2, ProcessInfo.processInfo.activeProcessorCount))
		do {
			guard let pool = receiver.pixelBufferPool else { throw CocoaError(.fileWriteUnknown) }
			for batchStart in stride(from: 0, to: frameCount, by: batchSize) {
				try Task.checkCancellation()
				let frames = batchStart..<min(batchStart + batchSize, frameCount)
				let buffers = try await withThrowingTaskGroup(of: (Int, CVReadOnlyPixelBuffer).self) { group in
					for frame in frames {
						group.addTask {
							var buffer = try pool.makeMutablePixelBuffer()
							buffer.accessUnsafeMutableRawPlaneBytes { planes in
								guard let plane = planes.first, let context = CGContext(data: plane.bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: plane.properties.bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return }
								draw(at: Double(frame) / Double(framesPerSecond), in: context, backdrop: backdrop, photoArea: photoArea, cornerRadius: cornerRadius, slides: slides)
							}
							return (frame, CVReadOnlyPixelBuffer(buffer))
						}
					}
					var buffers: [Int: CVReadOnlyPixelBuffer] = [:]
					for try await (frame, buffer) in group {
						buffers[frame] = buffer
					}
					return buffers
				}
				for frame in frames {
					guard let buffer = buffers[frame] else { continue }
					// Waits while the encoder catches up.
					try await receiver.append(buffer, with: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))
				}
				progress(Double(frames.upperBound) / Double(frameCount))
			}
		} catch {
			writer.cancelWriting()
			throw error
		}
		receiver.finish()
		await writer.finishWriting()
		if writer.status != .completed {
			throw writer.error ?? CocoaError(.fileWriteUnknown)
		}
	}

	private static let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

	/// Redraws an image in the video frames' pixel format.
	private static func matching(_ image: CGImage, colorSpace: CGColorSpace) -> CGImage {
		guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else { return image }
		context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
		return context.makeImage() ?? image
	}

	private static func draw(at time: Double, in context: CGContext, backdrop: CGImage, photoArea: CGRect, cornerRadius: CGFloat, slides: [Slide]) {
		let height = CGFloat(context.height)
		context.draw(backdrop, in: CGRect(x: 0, y: 0, width: CGFloat(context.width), height: height))
		guard !slides.isEmpty else { return }
		let index = min(Int(time / slideSeconds), slides.count - 1)
		let local = time - Double(index) * slideSeconds
		// The next photo fades in over the end of this one.
		let next = index + 1 < slides.count && local > slideSeconds - fadeSeconds ? (index: index + 1, alpha: (local - (slideSeconds - fadeSeconds)) / fadeSeconds) : nil
		// Core Graphics counts up from the bottom.
		let area = CGRect(x: photoArea.minX, y: height - photoArea.maxY, width: photoArea.width, height: photoArea.height)
		context.saveGState()
		context.addPath(CGPath(roundedRect: area, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
		context.clip()
		drawPhoto(slides[index], number: index, at: time, in: context, area: area, alpha: 1)
		if let next {
			drawPhoto(slides[next.index], number: next.index, at: time, in: context, area: area, alpha: next.alpha)
		}
		context.restoreGState()
		// Photos from the same year keep one steady label; a new year's label fades in with its photo.
		if let next, slides[next.index].year != slides[index].year {
			drawLabel(slides[index].label, in: context, area: area, alpha: 1 - next.alpha)
			drawLabel(slides[next.index].label, in: context, area: area, alpha: next.alpha)
		} else {
			drawLabel(slides[index].label, in: context, area: area, alpha: 1)
		}
	}

	/// Fills the area around the photo's focus, growing from the moment it starts fading in.
	private static func drawPhoto(_ slide: Slide, number: Int, at time: Double, in context: CGContext, area: CGRect, alpha: Double) {
		let start = number == 0 ? 0 : Double(number) * slideSeconds - fadeSeconds
		let progress = min(1, max(0, (time - start) / (slideSeconds + fadeSeconds)))
		let imageWidth = CGFloat(slide.image.width)
		let imageHeight = CGFloat(slide.image.height)
		let scale = max(area.width / imageWidth, area.height / imageHeight) * (1 + zoom * progress)
		let drawnWidth = imageWidth * scale
		let drawnHeight = imageHeight * scale
		let x = min(area.minX, max(area.maxX - drawnWidth, area.midX - slide.focus.x * drawnWidth))
		// Focus is measured from the top; this context's y runs from the bottom.
		let y = min(area.minY, max(area.maxY - drawnHeight, area.midY - (1 - slide.focus.y) * drawnHeight))
		context.setAlpha(alpha)
		context.interpolationQuality = .high
		context.draw(slide.image, in: CGRect(x: x, y: y, width: drawnWidth, height: drawnHeight))
		context.setAlpha(1)
	}

	private static func drawLabel(_ label: CGImage?, in context: CGContext, area: CGRect, alpha: Double) {
		guard let label, alpha > 0 else { return }
		let inset: CGFloat = 30
		context.setAlpha(alpha)
		context.draw(label, in: CGRect(x: area.minX + inset, y: area.minY + inset, width: CGFloat(label.width), height: CGFloat(label.height)))
		context.setAlpha(1)
	}
}
