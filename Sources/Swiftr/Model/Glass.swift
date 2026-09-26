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
}
