import Foundation

/// How exported Swift code is laid out, from Settings → Export.
struct CodeExportOptions: Equatable {
	enum Layout: String, CaseIterable, Identifiable {
		/// Everything in one `<App>App.swift`.
		case singleFile
		/// `<App>App.swift` plus one file per view in a views folder.
		case folder
		var id: String { rawValue }
	}

	enum Indent: String, CaseIterable, Identifiable {
		case fourSpaces, twoSpaces, tabs
		var id: String { rawValue }
		var unit: String {
			switch self {
			case .fourSpaces: "    "
			case .twoSpaces: "  "
			case .tabs: "\t"
			}
		}
	}

	var layout: Layout = .singleFile
	var viewsFolder = "Views"
	var includePreviews = true
	var indent: Indent = .fourSpaces

	enum Key {
		static let layout = "export.layout"
		static let viewsFolder = "export.viewsFolder"
		static let includePreviews = "export.includePreviews"
		static let indent = "export.indent"
	}

	/// The options as set in Settings.
	static var current: CodeExportOptions {
		let d = UserDefaults.standard
		var o = CodeExportOptions()
		o.layout = d.string(forKey: Key.layout).flatMap(Layout.init) ?? o.layout
		let folder = d.string(forKey: Key.viewsFolder)?.trimmingCharacters(in: .whitespaces) ?? ""
		if !folder.isEmpty { o.viewsFolder = folder }
		if d.object(forKey: Key.includePreviews) != nil {
			o.includePreviews = d.bool(forKey: Key.includePreviews)
		}
		o.indent = d.string(forKey: Key.indent).flatMap(Indent.init) ?? o.indent
		return o
	}

	/// Converts the generator's 4-space indentation to the chosen style.
	func reindent(_ code: String) -> String {
		guard indent != .fourSpaces else { return code }
		let lines = code.components(separatedBy: "\n").map { (line: String) -> String in
			let spaces = line.prefix { $0 == " " }.count
			return String(repeating: indent.unit, count: spaces / 4)
				+ String(repeating: " ", count: spaces % 4)
				+ String(line.dropFirst(spaces))
		}
		return lines.joined(separator: "\n")
	}
}
