// The App Store creative assets (iOS 27's product page header and search results image), in the screenshots' style: the app
// icon's dusk sky, the same photos and screens. Run with `fastlane creative_assets`, or directly:
//   xcrun swift bin/creative-assets.swift <photos folder> <raw screenshots folder> <out folder>
// Writes <out>/header.png, 3840 x 1646 (21:9): no text, so one for every language. A row of prints, one photo from each year
// with its year under it, low enough that the App Store's buttons over the top stay on sky. And <out>/<locale>/search-results.png,
// 3840 x 2560 (3:2): a headline in that language beside the day and widgets screens in bezels. PNG, the only image its upload takes,
// with no alpha, which it refuses.
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The search results headline in each App Store language: the locales of fastlane/metadata
let headlines = [
	"en-US": "Your photos from this day, in widgets",
	"de-DE": "Deine Fotos von diesem Tag, als Widgets",
	"es-ES": "Tus fotos de este día, en widgets",
	"es-MX": "Tus fotos de este día, en widgets",
	"fr-FR": "Vos photos de ce jour, en widgets",
	"it": "Le tue foto di questo giorno, nei widget",
	"ja": "過去の今日の\n写真を\nウィジェットで",
	"ko": "과거의 오늘\n사진을\n위젯으로",
	"pt-BR": "Suas fotos deste dia, em widgets",
	"zh-Hans": "那年今日\n的照片，\n就在小组件里",
]

/// One photo from each year, oldest first (bin/screenshot-support.zsh's photos, which give each its year)
let prints = [("post-viaduct-waterfront", 2019), ("grand-canyon-sunset", 2020), ("reflection-lake", 2021), ("crystal-ridge_2", 2022), ("rocky-mountain-national-park_1", 2023), ("Devereux-low-tide_1", 2024)]

// The icon's dusk, top to bottom: mauve sky warming to peach (bin/caption-screenshots.swift)
let sky = [(0.60, 0.42, 0.52), (0.71, 0.49, 0.52), (0.85, 0.63, 0.52)]

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
	FileHandle.standardError.write("Usage: creative-assets.swift <photos folder> <raw screenshots folder> <out folder>\n".data(using: .utf8)!)
	exit(2)
}
let photosFolder = URL(fileURLWithPath: arguments[1])
let rawFolder = URL(fileURLWithPath: arguments[2])
let outFolder = URL(fileURLWithPath: arguments[3])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func loadImage(_ url: URL) -> CGImage {
	guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
		FileHandle.standardError.write("Couldn't read \(url.path)\n".data(using: .utf8)!)
		exit(1)
	}
	return image
}

func save(_ image: CGImage, to url: URL) {
	try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
	let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
	CGImageDestinationAddImage(destination, image, nil)
	guard CGImageDestinationFinalize(destination) else { exit(1) }
	print("  \(url.path)")
}

/// A canvas drawn top-down, filled with the dusk sky and two soft glows
func canvas(width: Int, height: Int) -> CGContext {
	let w = CGFloat(width), h = CGFloat(height)
	let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
	context.translateBy(x: 0, y: h)
	context.scaleBy(x: 1, y: -1)
	let colors = sky.map { CGColor(colorSpace: colorSpace, components: [$0.0, $0.1, $0.2, 1])! } as CFArray
	let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.55, 1])!
	context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w * 0.2, y: h), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
	for (center, radius, color) in [(CGPoint(x: w * 0.8, y: h * 0.05), max(w, h) * 0.55, CGColor(gray: 1, alpha: 0.2)), (CGPoint(x: w * 0.12, y: h * 1.05), max(w, h) * 0.5, CGColor(srgbRed: 1, green: 0.8, blue: 0.62, alpha: 0.35))] {
		let glow = CGGradient(colorsSpace: colorSpace, colors: [color, color.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
		context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
	}
	return context
}

/// Draws `image` filling `rect` (top-down), cropped to its aspect from the center
func draw(_ image: CGImage, filling rect: CGRect, in context: CGContext) {
	let iw = CGFloat(image.width), ih = CGFloat(image.height)
	let scale = max(rect.width / iw, rect.height / ih)
	let crop = CGRect(x: (iw - rect.width / scale) / 2, y: (ih - rect.height / scale) / 2, width: rect.width / scale, height: rect.height / scale)
	guard let cropped = image.cropping(to: crop.integral) else { return }
	context.saveGState()
	context.clip(to: rect)
	context.interpolationQuality = .high
	context.translateBy(x: 0, y: rect.maxY + rect.minY)
	context.scaleBy(x: 1, y: -1)
	context.draw(cropped, in: rect)
	context.restoreGState()
}

/// The system font's rounded design, as the app uses
func roundedFont(size: CGFloat, weight: NSFont.Weight = .bold) -> CTFont {
	let font = NSFont.systemFont(ofSize: size, weight: weight)
	return NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: size) ?? font
}

/// Draws `text` in `rect` (top-down), wrapped, returning the height it took
@discardableResult
func drawText(_ text: String, in rect: CGRect, font: CTFont, color: CGColor, alignment: CTTextAlignment, context: CGContext, shadow: Bool = false) -> CGFloat {
	var alignment = alignment
	let style = withUnsafeBytes(of: &alignment) { bytes in
		var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: bytes.count, value: bytes.baseAddress!)
		return CTParagraphStyleCreate(&setting, 1)
	}
	let attributes: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color, kCTParagraphStyleAttributeName: style]
	let framesetter = CTFramesetterCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!)
	let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, CGSize(width: rect.width, height: .greatestFiniteMagnitude), nil)
	let textRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(size.height))
	context.saveGState()
	context.translateBy(x: 0, y: textRect.maxY + textRect.minY)
	context.scaleBy(x: 1, y: -1)
	if shadow {
		context.setShadow(offset: CGSize(width: 0, height: -4), blur: 24, color: CGColor(gray: 0, alpha: 0.25))
	}
	CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: textRect, transform: nil), nil), context)
	context.restoreGState()
	return textRect.height
}

/// Runs `body` with the context turned by `degrees` about `center`
func rotated(_ context: CGContext, by degrees: CGFloat, about center: CGPoint, _ body: () -> Void) {
	context.saveGState()
	context.translateBy(x: center.x, y: center.y)
	context.rotate(by: degrees * .pi / 180)
	context.translateBy(x: -center.x, y: -center.y)
	body()
	context.restoreGState()
}

// MARK: Product page header

func header() -> CGImage {
	let width = 3840, height = 1646
	let h = CGFloat(height)
	let context = canvas(width: width, height: height)
	// Prints a little taller than wide, below the middle: the top third stays sky, clear of the App Store's back and share
	// buttons over it
	let photoSize = CGSize(width: 600, height: 680)
	let border: CGFloat = 36, label: CGFloat = 136
	let card = CGSize(width: photoSize.width + 2 * border, height: photoSize.height + border + label)
	let step = card.width * 0.88
	let tilts: [CGFloat] = [-5, 3, -2, 4, -3, 2]
	let lifts: [CGFloat] = [20, -30, 10, -20, 30, -10]
	let centerY = h * 0.58
	let firstX = CGFloat(width) / 2 - step * CGFloat(prints.count - 1) / 2
	for (slot, (name, year)) in prints.enumerated() {
		let photo = loadImage(photosFolder.appendingPathComponent("\(name).avif"))
		let center = CGPoint(x: firstX + CGFloat(slot) * step, y: centerY + lifts[slot])
		let rect = CGRect(x: center.x - card.width / 2, y: center.y - card.height / 2, width: card.width, height: card.height)
		rotated(context, by: tilts[slot], about: center) {
			context.saveGState()
			context.setShadow(offset: CGSize(width: 0, height: 24), blur: 70, color: CGColor(gray: 0, alpha: 0.35))
			context.setFillColor(CGColor(srgbRed: 0.99, green: 0.98, blue: 0.96, alpha: 1))
			context.addPath(CGPath(roundedRect: rect, cornerWidth: 18, cornerHeight: 18, transform: nil))
			context.fillPath()
			context.restoreGState()
			draw(photo, filling: CGRect(x: rect.minX + border, y: rect.minY + border, width: photoSize.width, height: photoSize.height), in: context)
			let font = roundedFont(size: 80, weight: .semibold)
			drawText(String(year), in: CGRect(x: rect.minX, y: rect.maxY - label + 24, width: rect.width, height: label), font: font, color: CGColor(srgbRed: 0.42, green: 0.3, blue: 0.36, alpha: 1), alignment: .center, context: context)
		}
	}
	return context.makeImage()!
}

// MARK: Search results

/// Draws a screen in a thin black bezel, `height` tall with its top left at `origin`, turned by `tilt`
func drawPhone(_ screen: CGImage, height: CGFloat, center: CGPoint, tilt: CGFloat, context: CGContext) {
	let screenSize = CGSize(width: height * CGFloat(screen.width) / CGFloat(screen.height), height: height)
	let bezel = screenSize.width * 0.03
	let screenRect = CGRect(x: center.x - screenSize.width / 2, y: center.y - screenSize.height / 2, width: screenSize.width, height: screenSize.height)
	let corner = screenSize.width * 0.13
	rotated(context, by: tilt, about: center) {
		context.saveGState()
		context.setShadow(offset: CGSize(width: 0, height: 40), blur: 120, color: CGColor(gray: 0, alpha: 0.4))
		context.addPath(CGPath(roundedRect: screenRect.insetBy(dx: -bezel, dy: -bezel), cornerWidth: corner + bezel, cornerHeight: corner + bezel, transform: nil))
		context.setFillColor(CGColor(gray: 0.06, alpha: 1))
		context.fillPath()
		context.restoreGState()
		context.saveGState()
		context.addPath(CGPath(roundedRect: screenRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
		context.clip()
		draw(screen, filling: screenRect, in: context)
		context.restoreGState()
	}
}

func searchResults(headline: String, day: CGImage, widgets: CGImage) -> CGImage {
	let width = 3840, height = 2560
	let w = CGFloat(width), h = CGFloat(height)
	let context = canvas(width: width, height: height)
	// Two phones on the right: the widgets behind, the day in front
	let phoneHeight = h * 0.84
	drawPhone(widgets, height: phoneHeight, center: CGPoint(x: w * 0.6, y: h * 0.52), tilt: -6, context: context)
	drawPhone(day, height: phoneHeight, center: CGPoint(x: w * 0.81, y: h * 0.5), tilt: 4, context: context)
	// The headline on the left, big enough to read at the size search results show it, centered on the phones
	let column = CGRect(x: w * 0.06, y: 0, width: w * 0.36, height: h)
	// Lines broken by hand (Chinese, Japanese and Korean, which Core Text would split mid-word) shrink to fit the column
	var size: CGFloat = 215
	let widest = { (size: CGFloat) in headline.split(separator: "\n").map { CTLineGetTypographicBounds(CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, String($0) as CFString, [kCTFontAttributeName: roundedFont(size: size)] as CFDictionary)!), nil, nil, nil) }.max() ?? 0 }
	while headline.contains("\n"), widest(size) > column.width {
		size -= 5
	}
	let font = roundedFont(size: size)
	let measure = CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString(CFAttributedStringCreate(nil, headline as CFString, [kCTFontAttributeName: font] as CFDictionary)!), CFRange(), nil, CGSize(width: column.width, height: .greatestFiniteMagnitude), nil)
	drawText(headline, in: CGRect(x: column.minX, y: (h - measure.height) / 2 - h * 0.02, width: column.width, height: measure.height), font: font, color: CGColor(gray: 1, alpha: 1), alignment: .left, context: context, shadow: true)
	return context.makeImage()!
}

print("Creative assets:")
save(header(), to: outFolder.appendingPathComponent("header.png"))
let day = loadImage(rawFolder.appendingPathComponent("iPhone-2-day.jpg"))
let widgets = loadImage(rawFolder.appendingPathComponent("iPhone-1-widgets.jpg"))
for (locale, headline) in headlines.sorted(by: { $0.key < $1.key }) {
	save(searchResults(headline: headline, day: day, widgets: widgets), to: outFolder.appendingPathComponent(locale).appendingPathComponent("search-results.png"))
}
