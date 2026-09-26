import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum FilePanels {
	static func saveURL(suggestedName: String, type: UTType) -> URL? {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = suggestedName
		panel.allowedContentTypes = [type]
		return panel.runModal() == .OK ? panel.url : nil
	}

	static func save(_ string: String, suggestedName: String, type: UTType) {
		if let url = saveURL(suggestedName: suggestedName, type: type) {
			try? string.write(to: url, atomically: true, encoding: .utf8)
		}
	}

	static func openURL(types: [UTType]) -> URL? {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = types
		panel.allowsMultipleSelection = false
		return panel.runModal() == .OK ? panel.url : nil
	}
}

extension UTType {
	/// JSON with comments. Projects are saved as plain JSON but opened with comments allowed.
	static let jsonc = UTType(filenameExtension: "jsonc") ?? .json
}

/// The recent-projects list, kept in user defaults as file paths.
enum RecentProjects {
	private static let key = "recentProjects"

	static func load() -> [URL] {
		(UserDefaults.standard.stringArray(forKey: key) ?? []).map { URL(fileURLWithPath: $0) }
	}

	static func save(_ urls: [URL]) {
		UserDefaults.standard.set(urls.map(\.path), forKey: key)
	}
}
