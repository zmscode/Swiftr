import SwiftUI

/// The system's SF Symbols catalog: names in Apple's order, search keywords, and categories,
/// read from the CoreGlyphs bundle that ships with macOS.
@MainActor
enum SymbolCatalog {
	struct Category: Identifiable, Hashable {
		let key: String
		let icon: String
		var id: String { key }
		var title: String { SymbolCatalog.categoryTitles[key] ?? key.capitalized }
	}

	static let names: [String] = {
		let all = plist("symbol_order") as? [String] ?? fallback
		// Drop localized script variants like "character.book.closed.ar".
		return all.filter { name in
			guard let last = name.split(separator: ".").last else { return true }
			return !localeSuffixes.contains(String(last))
		}
	}()

	static let keywords: [String: [String]] = plist("symbol_search") as? [String: [String]] ?? [:]
	static let categoriesBySymbol: [String: [String]] =
		plist("symbol_categories") as? [String: [String]] ?? [:]

	static let categories: [Category] = {
		let raw = plist("categories") as? [[String: String]] ?? []
		return raw.compactMap { dict in
			guard let key = dict["key"], let icon = dict["icon"] else { return nil }
			return Category(key: key, icon: icon)
		}
	}()

	static func search(_ query: String, category: String?) -> [String] {
		let q = query.trimmingCharacters(in: .whitespaces).lowercased()
		return names.filter { name in
			if let category, category != "all",
				!(categoriesBySymbol[name]?.contains(category) ?? false)
			{
				return false
			}
			guard !q.isEmpty else { return true }
			if name.contains(q) { return true }
			return keywords[name]?.contains { $0.contains(q) } ?? false
		}
	}

	private static func plist(_ name: String) -> Any? {
		let url = URL(
			fileURLWithPath:
				"/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/\(name).plist")
		guard let data = try? Data(contentsOf: url) else { return nil }
		return try? PropertyListSerialization.propertyList(from: data, format: nil)
	}

	private static let localeSuffixes: Set<String> = [
		"ar", "he", "hi", "ja", "ko", "th", "zh", "el", "ru", "bn", "gu", "kn", "ml", "mr", "or",
		"pa", "ta", "te", "km", "my", "si", "lo", "sat", "mni", "rtl", "tr", "vi", "ug", "ur",
	]

	nonisolated private static let categoryTitles: [String: String] = [
		"all": "All", "whatsnew": "What's New", "draw": "Draw", "variable": "Variable",
		"multicolor": "Multicolor", "communication": "Communication", "weather": "Weather",
		"maps": "Maps", "objectsandtools": "Objects & Tools", "devices": "Devices",
		"cameraandphotos": "Camera & Photos", "gaming": "Gaming", "connectivity": "Connectivity",
		"transportation": "Transportation", "automotive": "Automotive",
		"accessibility": "Accessibility",
		"privacyandsecurity": "Privacy & Security", "human": "Human", "home": "Home",
		"fitness": "Fitness", "nature": "Nature", "editing": "Editing",
		"textformatting": "Text Formatting",
		"media": "Media", "keyboard": "Keyboard", "commerce": "Commerce", "time": "Time",
		"health": "Health", "shapes": "Shapes", "arrows": "Arrows", "indices": "Indices",
		"math": "Math",
	]

	/// Used if the system catalog can't be read.
	private static let fallback = [
		"star.fill", "heart.fill", "bolt.fill", "gearshape", "person.crop.circle", "house",
		"magnifyingglass", "bell", "trash", "folder", "doc.text", "paperplane.fill",
		"checkmark.circle.fill", "xmark.circle.fill", "exclamationmark.triangle", "info.circle",
	]
}
