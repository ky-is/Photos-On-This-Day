import Foundation

/// Links from the widget that open a photo in the app.
nonisolated enum DeepLink {
	static let scheme = "photosonthisday"

	static func photo(id: String) -> URL {
		var components = URLComponents()
		components.scheme = scheme
		components.host = "photo"
		components.queryItems = [URLQueryItem(name: "id", value: id)]
		return components.url!
	}

	/// The photo's local identifier, when `url` is a photo link.
	static func photoID(from url: URL) -> String? {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme == scheme, components.host == "photo" else { return nil }
		return components.queryItems?.first { $0.name == "id" }?.value
	}
}
