import Foundation

/// Files made only to be shared: originals exported from Photos, and collage videos. Each kind has its own folder in tmp,
/// cleared at launch and as new files are made, so they don't pile up until the system gets around to emptying tmp.
nonisolated enum TemporaryFiles {
	private static let exports = URL.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
	private static let collages = URL.temporaryDirectory.appending(path: "Collages", directoryHint: .isDirectory)

	static func clearAll() {
		for folder in [exports, collages] {
			try? FileManager.default.removeItem(at: folder)
		}
	}

	/// A new folder for one exported original. Earlier exports more than ten minutes old go first: their share sheets are done with them.
	static func newExportFolder() throws -> URL {
		let fileManager = FileManager.default
		let cutoff = Date.now.addingTimeInterval(-10 * 60)
		for folder in (try? fileManager.contentsOfDirectory(at: exports, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
			if let created = try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate, created < cutoff {
				try? fileManager.removeItem(at: folder)
			}
		}
		let folder = exports.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
		return folder
	}

	/// Where a collage video goes. Only the newest is kept: making one removes the others.
	static func collageVideo(named name: String) -> URL {
		let fileManager = FileManager.default
		try? fileManager.removeItem(at: collages)
		try? fileManager.createDirectory(at: collages, withIntermediateDirectories: true)
		return collages.appending(path: "\(name).mp4")
	}
}
