import SwiftUI

/// A drawn, looping demo of adding the widget: the Home Screen on iPhone and iPad, the desktop on a Mac. Each step plays
/// in a few beats; `HelpAddWidgetView` drives it and highlights the written step that goes with it.
struct AddWidgetAnimation: View {
	let step: Int
	let beat: Int

	/// How long each beat of each step lasts, in seconds: one array per written step.
	#if os(macOS)
	static let beats: [[Double]] = [[1.2, 1.0, 1.4], [1.0, 1.4, 1.2], [1.0, 1.4, 2.2]]
	#else
	static let beats: [[Double]] = [[1.0, 0.8, 1.4], [1.0, 1.0, 1.2], [1.0, 1.4, 1.2], [1.0, 1.2, 1.0, 2.2]]
	#endif

	/// The icon's dusk, as the App Store screenshots use: mauve sky warming to peach
	static let dusk = LinearGradient(colors: [Color(red: 0.60, green: 0.42, blue: 0.52), Color(red: 0.71, green: 0.49, blue: 0.52), Color(red: 0.85, green: 0.63, blue: 0.52)], startPoint: .top, endPoint: .bottom)

	/// Muted stand-ins for other apps' icons
	static let iconColors: [Color] = ([.blue, .green, .orange, .pink, .teal, .indigo, .yellow, .red, .mint, .purple, .cyan, .brown] as [Color]).map { $0.opacity(0.75) }

	var body: some View {
		#if os(macOS)
		DesktopScene(step: step, beat: beat)
		#else
		HomeScreenScene(step: step, beat: beat)
		#endif
	}
}

/// The photo the drawn widget shows: a sunset over hills
private struct WidgetArt: View {
	var body: some View {
		ZStack(alignment: .bottom) {
			LinearGradient(colors: [Color(red: 0.55, green: 0.65, blue: 0.80), Color(red: 0.98, green: 0.78, blue: 0.50)], startPoint: .top, endPoint: .bottom)
			Ellipse()
				.fill(Color(red: 0.35, green: 0.30, blue: 0.32))
				.scaleEffect(x: 1.6, y: 1, anchor: .bottom)
				.frame(height: 18)
				.offset(y: 8)
		}
			.clipShape(.rect(cornerRadius: 9))
	}
}

/// A fingertip, pressed down when `pressed`
private struct Fingertip: View {
	let pressed: Bool

	var body: some View {
		Circle()
			.fill(.white.opacity(0.75))
			.overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 1))
			.frame(width: 22, height: 22)
			.scaleEffect(pressed ? 0.8 : 1)
			.shadow(color: .black.opacity(0.3), radius: pressed ? 1 : 4, y: pressed ? 0 : 2)
	}
}

#if !os(macOS)
/// A phone's Home Screen: touch and hold until the apps jiggle, Edit, Add Widget, search, then pick a size and add it.
private struct HomeScreenScene: View {
	let step: Int
	let beat: Int

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private let width: CGFloat = 170
	private let height: CGFloat = 350
	private var screen: CGSize { CGSize(width: width - 12, height: height - 12) }

	private var jiggles: Bool { step >= 1 && !placed }
	private var showsMenu: Bool { step == 1 && beat >= 1 }
	private var showsSheet: Bool { step == 2 || (step == 3 && beat < 3) }
	private var placed: Bool { step == 3 && beat == 3 }

	var body: some View {
		ZStack {
			AddWidgetAnimation.dusk
			homeScreen
			if jiggles && !showsSheet {
				editButtons
			}
			if showsMenu {
				menu
					.transition(.scale(scale: 0.6, anchor: .topLeading).combined(with: .opacity))
			}
			if showsSheet {
				sheet
					.transition(.move(edge: .bottom))
			}
			if let finger {
				Fingertip(pressed: finger.pressed)
					.position(finger.point)
					.transition(.opacity)
			}
		}
			.frame(width: screen.width, height: screen.height)
			.clipShape(.rect(cornerRadius: 24))
			.padding(6)
			.background(.black, in: .rect(cornerRadius: 30))
			.frame(width: width, height: height)
	}

	// MARK: Home Screen

	private let columns = 4
	private let iconSize: CGFloat = 28
	private var iconSpacing: CGFloat { (screen.width - CGFloat(columns) * iconSize) / CGFloat(columns + 1) }
	private func iconCenter(column: Int, row: Int) -> CGPoint {
		CGPoint(x: iconSpacing + iconSize / 2 + CGFloat(column) * (iconSize + iconSpacing), y: 50 + CGFloat(row) * (iconSize + 18))
	}

	private var homeScreen: some View {
		ZStack {
			if placed {
				// The medium widget, in place of the first two rows
				let top = iconCenter(column: 0, row: 0), bottom = iconCenter(column: 3, row: 1)
				WidgetArt()
					.overlay(alignment: .bottomTrailing) {
						Text(verbatim: "2019")
							.font(.system(size: 7, weight: .semibold))
							.foregroundStyle(.white)
							.padding(5)
					}
					.frame(width: bottom.x - top.x + iconSize, height: bottom.y - top.y + iconSize)
					.position(x: (top.x + bottom.x) / 2, y: (top.y + bottom.y) / 2)
					.transition(.scale(scale: 1.3).combined(with: .opacity))
			}
			ForEach(0..<20, id: \.self) { index in
				let row = index / columns, column = index % columns
				if !(placed && row < 2) {
					let center = iconCenter(column: column, row: row)
					if center.y < screen.height - 70 {
						RoundedRectangle(cornerRadius: 7)
							.fill(AddWidgetAnimation.iconColors[index % AddWidgetAnimation.iconColors.count])
							.frame(width: iconSize, height: iconSize)
							.rotationEffect(.degrees(jiggles && !reduceMotion ? (index.isMultiple(of: 2) ? 2.5 : -2.5) : 0))
							.animation(jiggles && !reduceMotion ? .easeInOut(duration: 0.13).repeatForever() : .default, value: jiggles)
							.position(center)
					}
				}
			}
			// The dock
			RoundedRectangle(cornerRadius: 18)
				.fill(.white.opacity(0.25))
				.frame(width: screen.width - 12, height: 44)
				.overlay {
					HStack(spacing: iconSpacing) {
						ForEach(0..<4, id: \.self) { index in
							RoundedRectangle(cornerRadius: 7)
								.fill(AddWidgetAnimation.iconColors[(index + 5) % AddWidgetAnimation.iconColors.count])
								.frame(width: iconSize, height: iconSize)
						}
					}
				}
				.position(x: screen.width / 2, y: screen.height - 30)
		}
	}

	private var editButtons: some View {
		ZStack {
			pill("Edit")
				.position(x: 28, y: 18)
			pill("Done")
				.position(x: screen.width - 28, y: 18)
		}
			.transition(.opacity)
	}

	private func pill(_ title: LocalizedStringKey) -> some View {
		Text(title)
			.font(.system(size: 9, weight: .semibold))
			.foregroundStyle(.white)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(.white.opacity(0.3), in: .capsule)
	}

	private var menu: some View {
		VStack(alignment: .leading, spacing: 0) {
			Label("Add Widget", systemImage: "plus.square.on.square")
				.padding(8)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(beat == 2 ? Color.gray.opacity(0.25) : .clear)
			Divider()
			RoundedRectangle(cornerRadius: 2)
				.fill(.secondary.opacity(0.5))
				.frame(width: 50, height: 5)
				.padding(10)
		}
			.font(.system(size: 9, weight: .medium))
			.foregroundStyle(.black)
			.frame(width: 110)
			.background(.white.opacity(0.95), in: .rect(cornerRadius: 10))
			.position(x: 12 + 55, y: 32 + 26)
	}

	// MARK: Widget gallery

	private var sheet: some View {
		VStack(spacing: 10) {
			Capsule()
				.fill(.secondary.opacity(0.4))
				.frame(width: 30, height: 4)
			if step == 2 {
				search
			} else {
				sizes
			}
			Spacer(minLength: 0)
		}
			.padding(10)
			.frame(width: screen.width, height: screen.height - 40)
			.background(Color(white: 0.96), in: .rect(cornerRadius: 18))
			.position(x: screen.width / 2, y: 40 + (screen.height - 40) / 2 + 9)
			.foregroundStyle(.black)
	}

	private var search: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 4) {
				Image(systemName: "magnifyingglass")
				if beat >= 1 {
					Text(verbatim: "On This Day")
						.transition(.opacity)
				}
				Spacer(minLength: 0)
			}
				.font(.system(size: 9))
				.foregroundStyle(beat >= 1 ? .black : .secondary)
				.padding(6)
				.background(Color(white: 0.88), in: .capsule)
			if beat >= 1 {
				HStack(spacing: 6) {
					Image("ShareBadge")
						.resizable()
						.frame(width: 22, height: 22)
						.clipShape(.rect(cornerRadius: 5))
					Text(verbatim: "On This Day")
						.font(.system(size: 9, weight: .semibold))
					Spacer(minLength: 0)
				}
					.padding(5)
					.background(beat == 2 ? Color.gray.opacity(0.25) : .clear, in: .rect(cornerRadius: 6))
					.transition(.opacity)
			} else {
				ForEach(0..<3, id: \.self) { index in
					HStack(spacing: 6) {
						RoundedRectangle(cornerRadius: 5)
							.fill(AddWidgetAnimation.iconColors[index + 2])
							.frame(width: 22, height: 22)
						RoundedRectangle(cornerRadius: 2)
							.fill(.secondary.opacity(0.4))
							.frame(width: 50, height: 5)
					}
						.padding(5)
				}
			}
		}
	}

	private var sizes: some View {
		VStack(spacing: 12) {
			Text(verbatim: "On This Day")
				.font(.system(size: 10, weight: .semibold))
			WidgetArt()
				.frame(width: beat == 0 ? 64 : 130, height: 64)
				.shadow(color: .black.opacity(0.15), radius: 6, y: 3)
				.frame(height: 90)
			HStack(spacing: 4) {
				ForEach(0..<3, id: \.self) { index in
					Circle()
						.fill(index == min(beat, 1) ? Color.black.opacity(0.7) : Color.black.opacity(0.2))
						.frame(width: 4, height: 4)
				}
			}
			Spacer(minLength: 30)
			Text("Add Widget")
				.font(.system(size: 9, weight: .semibold))
				.foregroundStyle(.white)
				.padding(.horizontal, 14)
				.padding(.vertical, 6)
				.background(.blue, in: .capsule)
				.scaleEffect(beat == 2 ? 0.92 : 1)
		}
			.frame(height: 230)
	}

	// MARK: The finger

	private var finger: (point: CGPoint, pressed: Bool)? {
		switch (step, beat) {
		case (0, 0): (CGPoint(x: screen.width / 2, y: 250), false)
		case (0, _): (CGPoint(x: screen.width / 2, y: 250), true)
		case (1, 0): (CGPoint(x: 28, y: 18), true)
		case (1, 1): (CGPoint(x: 60, y: 50), false)
		case (1, _): (CGPoint(x: 50, y: 46), true)
		case (2, 0): (CGPoint(x: 80, y: 66), true)
		case (2, 1): (CGPoint(x: 90, y: 140), false)
		case (2, _): (CGPoint(x: 60, y: 102), true)
		case (3, 0): (CGPoint(x: 120, y: 140), true)
		case (3, 1): (CGPoint(x: 40, y: 140), false)
		case (3, 2): (CGPoint(x: screen.width / 2, y: 290), true)
		default: nil
		}
	}
}
#endif

#if os(macOS)
/// A Mac desktop: Control-click it, Edit Widgets, search, then drag the widget out.
private struct DesktopScene: View {
	let step: Int
	let beat: Int

	private let size = CGSize(width: 300, height: 190)

	private var showsMenu: Bool { step == 0 && beat >= 1 }
	private var showsGallery: Bool { step == 1 || (step == 2 && beat < 2) }
	private var placed: Bool { step == 2 && beat == 2 }

	var body: some View {
		ZStack {
			AddWidgetAnimation.dusk
			// The menu bar
			Rectangle()
				.fill(.white.opacity(0.3))
				.frame(height: 10)
				.frame(maxHeight: .infinity, alignment: .top)
			if placed {
				WidgetArt()
					.frame(width: 90, height: 44)
					.position(x: 60, y: 42)
					.transition(.opacity)
			}
			if showsMenu {
				menu
					.transition(.opacity)
			}
			if showsGallery {
				gallery
					.transition(.move(edge: .bottom))
			}
			if step == 2 && beat < 2 {
				// Picked up from the gallery, then dropped at the top left
				WidgetArt()
					.frame(width: 90, height: 44)
					.shadow(color: .black.opacity(0.3), radius: 6, y: 3)
					.position(beat == 0 ? CGPoint(x: 197, y: 148) : CGPoint(x: 60, y: 42))
			}
			if let cursor {
				Image(systemName: "cursorarrow")
					.font(.system(size: 14))
					.foregroundStyle(.black)
					.shadow(color: .white, radius: 1)
					.position(x: cursor.x + 4, y: cursor.y + 6)
			}
		}
			.frame(width: size.width, height: size.height)
			.clipShape(.rect(cornerRadius: 8))
			.padding(6)
			.background(Color(white: 0.15), in: .rect(cornerRadius: 12))
	}

	private var menu: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(0..<2, id: \.self) { _ in
				RoundedRectangle(cornerRadius: 2)
					.fill(.secondary.opacity(0.5))
					.frame(width: 60, height: 5)
			}
			Text("Edit Widgets")
				.font(.system(size: 9))
				.foregroundStyle(beat == 2 ? .white : .black)
				.padding(.horizontal, 4)
				.padding(.vertical, 2)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(beat == 2 ? Color.blue : .clear, in: .rect(cornerRadius: 3))
		}
			.padding(6)
			.frame(width: 110)
			.background(.white.opacity(0.95), in: .rect(cornerRadius: 6))
			.position(x: 150 + 55, y: 70 + 22)
	}

	private var gallery: some View {
		HStack(alignment: .top, spacing: 10) {
			VStack(alignment: .leading, spacing: 6) {
				HStack(spacing: 3) {
					Image(systemName: "magnifyingglass")
					if step >= 1 && (beat >= 1 || step == 2) {
						Text(verbatim: "On This Day")
					}
				}
					.font(.system(size: 7))
					.padding(4)
					.frame(width: 80, alignment: .leading)
					.background(Color(white: 0.88), in: .rect(cornerRadius: 4))
				HStack(spacing: 4) {
					Image("ShareBadge")
						.resizable()
						.frame(width: 14, height: 14)
						.clipShape(.rect(cornerRadius: 3))
					Text(verbatim: "On This Day")
						.font(.system(size: 7, weight: .semibold))
				}
					.opacity(step == 2 || beat >= 1 ? 1 : 0)
			}
			HStack(spacing: 8) {
				WidgetArt()
					.frame(width: 44, height: 44)
				WidgetArt()
					.frame(width: 90, height: 44)
					.opacity(step == 2 ? 0.3 : 1)
			}
				.opacity(step == 2 || beat == 2 ? 1 : 0)
		}
			.foregroundStyle(.black)
			.padding(10)
			.frame(width: size.width, height: 74, alignment: .topLeading)
			.background(Color(white: 0.96))
			.position(x: size.width / 2, y: size.height - 37)
	}

	private var cursor: CGPoint? {
		switch (step, beat) {
		case (0, 0): CGPoint(x: 150, y: 70)
		case (0, 1): CGPoint(x: 150, y: 70)
		case (0, _): CGPoint(x: 180, y: 108)
		case (1, _): CGPoint(x: 70, y: 140)
		case (2, 0): CGPoint(x: 197, y: 148)
		case (2, 1): CGPoint(x: 80, y: 46)
		default: nil
		}
	}
}
#endif

#Preview {
	AddWidgetAnimation(step: 1, beat: 2)
		.padding()
}
