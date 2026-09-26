import SwiftUI

/// Liquid Glass (macOS 26): `.glassEffect(_:in:)`.
enum GlassVariant: String, Codable, CaseIterable, Identifiable {
	case regular, clear
	var id: String { rawValue }
}

enum GlassShape: String, Codable, CaseIterable, Identifiable {
	case roundedRect, capsule, circle
	var id: String { rawValue }
	var title: String { self == .roundedRect ? "Rect" : rawValue.capitalized }
}

struct GlassSettings: Codable, Equatable {
	var variant: GlassVariant = .regular
	var tint: RGBA? = nil
	var interactive = false
	var shape: GlassShape = .capsule
	/// Take variant, tint and interactivity from the project theme; shape stays per-component.
	var followsTheme = true
}

extension GlassSettings {
	/// Glass saved before project themes kept its own look.
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		self.init()
		variant = (try? c.decodeIfPresent(GlassVariant.self, forKey: .variant)) ?? .regular
		tint = try? c.decodeIfPresent(RGBA.self, forKey: .tint)
		interactive = (try? c.decodeIfPresent(Bool.self, forKey: .interactive)) ?? false
		shape = (try? c.decodeIfPresent(GlassShape.self, forKey: .shape)) ?? .capsule
		followsTheme = (try? c.decodeIfPresent(Bool.self, forKey: .followsTheme)) ?? false
	}
}
