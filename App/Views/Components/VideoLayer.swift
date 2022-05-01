import AVKit
import SwiftUI

final class VideoLayerUIView: UIView {
	override static var layerClass: AnyClass { AVPlayerLayer.self }

	var player: AVPlayer? {
		get { playerLayer.player }
		set { playerLayer.player = newValue }
	}

	private var playerLayer: AVPlayerLayer {
		layer as! AVPlayerLayer
	}
}

struct VideoLayer: UIViewRepresentable {
	let player: AVPlayer

	func makeUIView(context: Context) -> VideoLayerUIView {
		let view = VideoLayerUIView()
		view.player = player
		return view
	}

	func updateUIView(_ uiView: VideoLayerUIView, context: Context) {
		uiView.player = player
	}
}
