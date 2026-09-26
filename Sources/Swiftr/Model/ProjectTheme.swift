import SwiftUI

/// The designed app's colour scheme: one accent every control shares, a palette of scheme colours
/// offered in the colour pickers (and for charts), and the Liquid Glass look components can follow.
struct ProjectTheme: Codable, Equatable {
	/// The app-wide accent (`.tint` on every window). Nil uses the system accent.
	var accent: RGBA? = nil
	var palette: [RGBA] = []
	var glass = ThemeGlass()

	/// The preset this theme matches exactly, if any.
	var preset: ThemePreset? {
		ThemePreset.allCases.first { $0.theme(keepingGlass: glass) == self }
	}

	/// Whether the generated app needs a `Theme` type: something follows the theme.
	func isUsed(by project: Project) -> Bool {
		accent != nil || project.usesThemeGlass
	}
}

extension ProjectTheme {
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		self.init()
		accent = try? c.decodeIfPresent(RGBA.self, forKey: .accent)
		palette = (try? c.decodeIfPresent([RGBA].self, forKey: .palette)) ?? []
		glass = (try? c.decodeIfPresent(ThemeGlass.self, forKey: .glass)) ?? ThemeGlass()
	}
}

/// Where the theme's glass takes its tint from.
enum GlassTintSource: String, Codable, CaseIterable, Identifiable {
	case none, accent, custom
	var id: String { rawValue }
	var title: String { rawValue.capitalized }
}

/// The Liquid Glass settings shared by every component set to follow the theme. Shape stays
/// per-component.
struct ThemeGlass: Codable, Equatable {
	var variant: GlassVariant = .regular
	var tintSource: GlassTintSource = .none
	var customTint = RGBA(r: 0, g: 0.48, b: 1, a: 0.35)
	var interactive = false

	/// A short description, e.g. "Regular · accent tint · interactive".
	var summary: String {
		var parts = [variant == .clear ? "Clear" : "Regular"]
		if tintSource != .none { parts.append("\(tintSource.rawValue) tint") }
		if interactive { parts.append("interactive") }
		return parts.joined(separator: " · ")
	}

	/// The tint colour, resolved against the theme's accent (the system accent when that's unset).
	func tint(accent: RGBA?) -> RGBA? {
		switch tintSource {
		case .none: nil
		case .accent: (accent ?? RGBA(Color(nsColor: .controlAccentColor))).withAlpha(0.35)
		case .custom: customTint
		}
	}
}

extension ThemeGlass {
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		let d = ThemeGlass()
		self.init()
		variant = (try? c.decodeIfPresent(GlassVariant.self, forKey: .variant)) ?? d.variant
		tintSource =
			(try? c.decodeIfPresent(GlassTintSource.self, forKey: .tintSource)) ?? d.tintSource
		customTint = (try? c.decodeIfPresent(RGBA.self, forKey: .customTint)) ?? d.customTint
		interactive = (try? c.decodeIfPresent(Bool.self, forKey: .interactive)) ?? d.interactive
	}
}

/// Ready-made schemes: an accent plus four supporting colours.
enum ThemePreset: String, CaseIterable, Identifiable {
	case system, ocean, forest, sunset, berry, graphite
	var id: String { rawValue }
	var title: String { rawValue.capitalized }

	var colors: [String] {
		switch self {
		case .system: []
		case .ocean: ["0A84FF", "5AC8FA", "30B0C7", "1D3D5C", "E3F2FD"]
		case .forest: ["34A853", "7CB342", "2E7D32", "A1887F", "F1F8E9"]
		case .sunset: ["FF6B35", "F7C548", "E4572E", "A23B72", "FFF3E0"]
		case .berry: ["AF52DE", "FF2D92", "5856D6", "FF9F0A", "F3E5F5"]
		case .graphite: ["5E5CE6", "8E8E93", "3A3A3C", "C7C7CC", "F2F2F7"]
		}
	}

	/// The preset as a theme, keeping the given glass settings (presets only set colours).
	func theme(keepingGlass glass: ThemeGlass) -> ProjectTheme {
		let rgba = colors.compactMap(RGBA.init(hex:))
		return ProjectTheme(accent: rgba.first, palette: Array(rgba.dropFirst()), glass: glass)
	}
}

extension RGBA {
	init?(hex: String) {
		let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
		guard digits.count == 6, let v = UInt32(digits, radix: 16) else { return nil }
		self.init(
			r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255,
			b: Double(v & 0xFF) / 255)
	}

	func withAlpha(_ a: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: a) }
}

extension GlassSettings {
	/// These settings with the theme's variant, tint and interactivity when following the theme.
	func resolved(_ theme: ProjectTheme) -> GlassSettings {
		guard followsTheme else { return self }
		var g = self
		g.variant = theme.glass.variant
		g.tint = theme.glass.tint(accent: theme.accent)
		g.interactive = theme.glass.interactive
		return g
	}
}

extension Props {
	/// The props as drawn: glass that follows the theme takes the theme's look.
	func themed(_ theme: ProjectTheme) -> Props {
		guard let glass, glass.followsTheme else { return self }
		var p = self
		p.glass = glass.resolved(theme)
		return p
	}
}

extension Project {
	/// Any component's glass follows the theme.
	var usesThemeGlass: Bool {
		windows.contains { w in
			var root = w.root
			var found = false
			root.forEach { if $0.props.glass?.followsTheme == true { found = true } }
			return found
		}
	}
}
