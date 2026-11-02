// Turns the raw App Store screenshots into captioned ones of the same size: a line of text over the app icon's dusk sky,
// above the screen in a thin black bezel, in one App Store language. Run by bin/app-store-screenshots.zsh, or directly:
//   xcrun swift bin/caption-screenshots.swift <raw folder> <out folder> <locale>
// A file is captioned by the end of its name (iPhone-2-day.jpg is "day"); one with no caption here is left out. A Mac shot
// (Mac-*.jpg, a window from bin/mac-screenshots.zsh) is set on a desktop instead: the same sky with soft glows as a quiet
// wallpaper, the window with its own rounded corners, and beside it the app's widgets, cut from iPad-1-widgets.jpg (the same
// photos, drawn by WidgetKit; a Mac's own desktop widgets would show its own library).
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Each App Store language's captions, by shot: the locales of fastlane/metadata
let allCaptions = [
	"en-US": ["widgets": "Years ago today, right on your Home Screen", "day": "Every photo from this day, mapped", "share-video": "Share the day as a slideshow video", "closed-day": "Your day, even folded shut"],
	"de-DE": ["widgets": "Heute vor Jahren, auf dem Home-Bildschirm", "day": "Jedes Foto von diesem Tag, auf der Karte", "share-video": "Teile den Tag als Diashow-Video", "closed-day": "Dein Tag, auch zugeklappt"],
	"es-ES": ["widgets": "Un día como hoy, en tu pantalla de inicio", "day": "Cada foto de este día, en el mapa", "share-video": "Comparte el día en un vídeo", "closed-day": "Tu día, incluso plegado"],
	"es-MX": ["widgets": "Un día como hoy, en tu pantalla de inicio", "day": "Cada foto de este día, en el mapa", "share-video": "Comparte el día en un video", "closed-day": "Tu día, incluso plegado"],
	"fr-FR": ["widgets": "Il y a des années, sur votre écran d’accueil", "day": "Chaque photo de ce jour, sur une carte", "share-video": "Partagez la journée en vidéo", "closed-day": "Votre journée, même replié"],
	"it": ["widgets": "Accadde oggi, sulla schermata Home", "day": "Ogni foto di questo giorno, sulla mappa", "share-video": "Condividi la giornata in un video", "closed-day": "La tua giornata, anche da chiuso"],
	"ja": ["widgets": "過去の今日を、ホーム画面に", "day": "この日の写真を、すべて地図で", "share-video": "その日を動画で共有", "closed-day": "閉じたままでも、あの日を"],
	"ko": ["widgets": "과거의 오늘을 홈 화면에서", "day": "이날의 모든 사진을 지도로", "share-video": "그날을 동영상으로 공유", "closed-day": "접은 채로도 그날의 추억을"],
	"pt-BR": ["widgets": "Anos atrás, neste dia, na sua tela de início", "day": "Cada foto deste dia, no mapa", "share-video": "Compartilhe o dia em um vídeo", "closed-day": "Seu dia, mesmo dobrado"],
	"zh-Hans": ["widgets": "那年今日，就在主屏幕上", "day": "这一天的每张照片，\n都在地图上", "share-video": "将这一天分享为幻灯片视频", "closed-day": "合上手机，也能重温这一天"],
]

/// The Mac's day shot shows the whole day, with the widgets beside it
let macDayCaptions = ["en-US": "All your photos from this day", "de-DE": "Alle deine Fotos von diesem Tag", "es-ES": "Todas tus fotos de este día", "es-MX": "Todas tus fotos de este día", "fr-FR": "Toutes vos photos de ce jour", "it": "Tutte le tue foto di questo giorno", "ja": "この日の写真を、すべて", "ko": "이날의 모든 사진", "pt-BR": "Todas as suas fotos deste dia", "zh-Hans": "这一天的所有照片"]

// The icon's dusk, top to bottom: mauve sky warming to peach
let sky = [(0.60, 0.42, 0.52), (0.71, 0.49, 0.52), (0.85, 0.63, 0.52)]

let arguments = CommandLine.arguments
guard arguments.count == 4, let localeCaptions = allCaptions[arguments[3]] else {
	FileHandle.standardError.write("Usage: caption-screenshots.swift <raw folder> <out folder> <\(allCaptions.keys.sorted().joined(separator: "|"))>\n".data(using: .utf8)!)
	exit(2)
}
// The Duo's open day shows what the iPhone and iPad day does
let captions = localeCaptions.merging(["open-tall-day": localeCaptions["day"]!]) { kept, _ in kept }
let rawFolder = URL(fileURLWithPath: arguments[1])
let outFolder = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outFolder, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func loadImage(_ url: URL) -> CGImage? {
	guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
	return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

/// The Mac shots' widgets: the medium, large and small ones (in that order) from the iPad widgets shot, where the Today View
/// has them at these pixels (bin/app-store-screenshots.zsh's today_view)
struct Desktop {
	let widgets: [CGImage]
	/// The iPad's widget corners, in its pixels
	static let widgetCorner: CGFloat = 44

	init?(folder: URL) {
		guard let iPad = loadImage(folder.appendingPathComponent("iPad-1-widgets.jpg")), iPad.width == 2064 else { return nil }
		let rects = [CGRect(x: 128, y: 520, width: 712, height: 320), CGRect(x: 128, y: 912, width: 712, height: 712), CGRect(x: 128, y: 128, width: 320, height: 320)]
		let widgets = rects.compactMap { iPad.cropping(to: $0) }
		guard widgets.count == 3 else { return nil }
		self.widgets = widgets
	}
}
let desktop = Desktop(folder: rawFolder)

func caption(for file: String) -> String? {
	let name = (file as NSString).deletingPathExtension
	if name == "Mac-1-day" { return macDayCaptions[arguments[3]] }
	return captions.keys.sorted { $0.count > $1.count }.first { name.hasSuffix("-" + $0) }.flatMap { captions[$0] }
}

/// The system font's rounded design, bold, as the app uses
func roundedFont(size: CGFloat) -> CTFont {
	let bold = NSFont.systemFont(ofSize: size, weight: .bold)
	return NSFont(descriptor: bold.fontDescriptor.withDesign(.rounded) ?? bold.fontDescriptor, size: size) ?? bold
}

/// Draws `image` into `rect` (top-down coordinates), clipped to rounded corners, with a soft shadow
func drawCard(_ image: CGImage, in rect: CGRect, corner: CGFloat, context: CGContext, short: CGFloat) {
	let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: short * 0.01), blur: short * 0.035, color: CGColor(gray: 0, alpha: 0.4))
	context.addPath(path)
	context.setFillColor(CGColor(gray: 1, alpha: 1))
	context.fillPath()
	context.restoreGState()
	context.saveGState()
	context.addPath(path)
	context.clip()
	context.interpolationQuality = .high
	context.translateBy(x: 0, y: rect.maxY + rect.minY)
	context.scaleBy(x: 1, y: -1)
	context.draw(image, in: rect)
	context.restoreGState()
}

func draw(_ screen: CGImage, caption text: String, isWindow: Bool) -> CGImage? {
	let width = screen.width, height = screen.height
	let w = CGFloat(width), h = CGFloat(height)
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
	// Drawn top-down
	context.translateBy(x: 0, y: h)
	context.scaleBy(x: 1, y: -1)

	let colors = sky.map { CGColor(colorSpace: colorSpace, components: [$0.0, $0.1, $0.2, 1])! } as CFArray
	let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.55, 1])!
	context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
	if isWindow {
		// A quiet wallpaper: soft glows, light up high and warm low, so nothing competes with the photos
		for (center, radius, color) in [(CGPoint(x: w * 0.82, y: h * 0.12), w * 0.75, CGColor(gray: 1, alpha: 0.22)), (CGPoint(x: w * 0.1, y: h * 1.05), w * 0.7, CGColor(srgbRed: 1, green: 0.8, blue: 0.62, alpha: 0.35))] {
			let glow = CGGradient(colorsSpace: colorSpace, colors: [color, color.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
			context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
		}
	}

	// The caption, centered and wrapped, up to three lines
	let short = min(w, h)
	let fontSize = (short * 0.072).rounded()
	let margin = short * 0.08
	var alignment = CTTextAlignment.center
	let style = withUnsafeBytes(of: &alignment) { bytes in
		var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: bytes.count, value: bytes.baseAddress!)
		return CTParagraphStyleCreate(&setting, 1)
	}
	let attributes: [CFString: Any] = [kCTFontAttributeName: roundedFont(size: fontSize), kCTForegroundColorAttributeName: CGColor(gray: 1, alpha: 1), kCTParagraphStyleAttributeName: style]
	let string = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
	let framesetter = CTFramesetterCreateWithAttributedString(string)
	// Balanced: as narrow as it can be without taking another line, so no line ends up with a lone word
	let lineCount = { (width: CGFloat) -> Int in
		let frame = CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 10_000), transform: nil), nil)
		return CFArrayGetCount(CTFrameGetLines(frame))
	}
	let widest = w - 2 * margin
	let lines = lineCount(widest)
	var textWidth = widest
	while textWidth > widest / 2, lineCount(textWidth - fontSize / 4) == lines {
		textWidth -= fontSize / 4
	}
	let fitted = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, CGSize(width: textWidth, height: .greatestFiniteMagnitude), nil)
	let textTop = h * (w < h ? 0.055 : 0.06)
	let textRect = CGRect(x: (w - textWidth) / 2, y: textTop, width: textWidth, height: ceil(fitted.height))
	context.saveGState()
	// Core Text draws bottom-up: flip back for the text
	context.translateBy(x: 0, y: textRect.maxY + textRect.minY)
	context.scaleBy(x: 1, y: -1)
	context.setShadow(offset: CGSize(width: 0, height: -short * 0.002), blur: short * 0.012, color: CGColor(gray: 0, alpha: 0.25))
	let frame = CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: textRect, transform: nil), nil)
	CTFrameDraw(frame, context)
	context.restoreGState()

	// On a desktop: the widgets in a column on the left, the window filling the rest
	if isWindow, let desktop {
		let top = textRect.maxY + short * 0.07
		let margin = w * 0.04, gap = w * 0.025
		let windowHeight = h - top - h * 0.05
		let windowSize = CGSize(width: windowHeight * w / h, height: windowHeight)
		let windowRect = CGRect(x: w - margin - windowSize.width, y: top, width: windowSize.width, height: windowSize.height)
		// The widgets as wide as the space left, stacked from the top: medium, large, then small
		let columnWidth = windowRect.minX - gap - margin
		let scale = columnWidth / CGFloat(desktop.widgets[0].width)
		let widgetGap = gap * 0.6
		var y = top
		for widget in desktop.widgets {
			let size = CGSize(width: CGFloat(widget.width) * scale, height: CGFloat(widget.height) * scale)
			guard y + size.height <= h - h * 0.03 else { break }
			drawCard(widget, in: CGRect(x: margin, y: y, width: size.width, height: size.height), corner: Desktop.widgetCorner * scale, context: context, short: short)
			y += size.height + widgetGap
		}
		drawCard(screen, in: windowRect, corner: windowSize.height * 26 / 900, context: context, short: short)
		return context.makeImage()
	}

	// The screen below it, in a bezel, as large as fits
	let top = textRect.maxY + short * 0.06
	let bottom = h * 0.04
	let bezelShare = isWindow ? 0 : 0.022
	let available = CGSize(width: w * 0.86, height: h - top - bottom)
	let scale = min(available.width / (w * (1 + 2 * bezelShare)), available.height / (h + 2 * w * bezelShare))
	let screenSize = CGSize(width: w * scale, height: h * scale)
	let bezel = screenSize.width * bezelShare
	let screenRect = CGRect(x: (w - screenSize.width) / 2, y: top + bezel, width: screenSize.width, height: screenSize.height)
	// A phone's corners are rounder than an iPad's; a Mac window's are 26 points of 900
	let cornerShare = isWindow ? 26 / 900 : w < h ? (w / h < 0.6 ? 0.13 : 0.035) : 0.05
	let corner = min(screenSize.width, screenSize.height) * cornerShare
	let bezelRect = screenRect.insetBy(dx: -bezel, dy: -bezel)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: short * 0.012), blur: short * 0.04, color: CGColor(gray: 0, alpha: 0.35))
	context.addPath(CGPath(roundedRect: bezelRect, cornerWidth: corner + bezel, cornerHeight: corner + bezel, transform: nil))
	context.setFillColor(CGColor(gray: 0.06, alpha: 1))
	context.fillPath()
	context.restoreGState()
	context.saveGState()
	context.addPath(CGPath(roundedRect: screenRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
	context.clip()
	context.interpolationQuality = .high
	// Images draw bottom-up too
	context.translateBy(x: 0, y: screenRect.maxY + screenRect.minY)
	context.scaleBy(x: 1, y: -1)
	context.draw(screen, in: screenRect)
	context.restoreGState()
	return context.makeImage()
}

let files = try FileManager.default.contentsOfDirectory(atPath: rawFolder.path).filter { $0.hasSuffix(".jpg") }.sorted()
for file in files {
	guard let text = caption(for: file) else {
		print("  \(file): no caption, left out")
		continue
	}
	if file.hasPrefix("Mac-"), desktop == nil {
		print("  \(file): needs iPad-1-widgets.jpg beside it")
		exit(1)
	}
	guard let source = CGImageSourceCreateWithURL(rawFolder.appendingPathComponent(file) as CFURL, nil), let screen = CGImageSourceCreateImageAtIndex(source, 0, nil), let image = draw(screen, caption: text, isWindow: file.hasPrefix("Mac-")) else {
		print("  \(file): couldn't draw")
		exit(1)
	}
	let url = outFolder.appendingPathComponent(file)
	guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { exit(1) }
	CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
	CGImageDestinationFinalize(destination)
}
