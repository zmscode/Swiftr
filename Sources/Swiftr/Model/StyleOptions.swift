import AppKit
import SwiftUI

struct RGBA: Codable, Equatable {
	var r: Double, g: Double, b: Double, a: Double

	init(r: Double, g: Double, b: Double, a: Double = 1) {
		self.r = r
		self.g = g
		self.b = b
		self.a = a
	}

	init(_ color: Color) {
		let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
		r = Double(ns.redComponent)
		g = Double(ns.greenComponent)
		b = Double(ns.blueComponent)
		a = Double(ns.alphaComponent)
	}

	var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

	var hex: String {
		let v = [r, g, b].map { Int(($0 * 255).rounded()).clamped(to: 0...255) }
		return String(format: "#%02X%02X%02X", v[0], v[1], v[2])
	}

	static let black = RGBA(r: 0, g: 0, b: 0)
	static let white = RGBA(r: 1, g: 1, b: 1)
	static let blue = RGBA(r: 0.0, g: 0.48, b: 1.0)
	static let lightGray = RGBA(r: 0.9, g: 0.9, b: 0.92)
}

enum FontWeight: String, Codable, CaseIterable, Identifiable {
	case regular, medium, semibold, bold, heavy
	var id: String { rawValue }
	var fontWeight: Font.Weight {
		switch self {
		case .regular: .regular
		case .medium: .medium
		case .semibold: .semibold
		case .bold: .bold
		case .heavy: .heavy
		}
	}
}

enum StackAlign: String, Codable, CaseIterable, Identifiable {
	case start, center, end
	var id: String { rawValue }

	var horizontal: HorizontalAlignment {
		switch self {
		case .start: .leading
		case .center: .center
		case .end: .trailing
		}
	}

	var vertical: VerticalAlignment {
		switch self {
		case .start: .top
		case .center: .center
		case .end: .bottom
		}
	}

	/// Name used in the inspector and in generated code, depending on stack direction.
	func name(for kind: ComponentKind) -> String {
		switch (self, kind) {
		case (.start, .hstack): "top"
		case (.end, .hstack): "bottom"
		case (.start, _): "leading"
		case (.end, _): "trailing"
		default: "center"
		}
	}
}

/// How an image fits its frame: whole image visible, or filling the frame and cropped.
/// How an image fits its frame: whole image visible (fit), filling the frame and cropped (fill),
/// or distorted to the frame's exact shape (stretch).
enum ContentModeOption: String, Codable, CaseIterable, Identifiable {
	case fit, fill, stretch
	var id: String { rawValue }
}

/// A point within a frame, e.g. which part of an image stays visible when it's cropped.
enum AnchorOption: String, Codable, CaseIterable, Identifiable {
	case topLeading, top, topTrailing, leading, center, trailing, bottomLeading, bottom,
		bottomTrailing
	var id: String { rawValue }

	/// "Top left", "Center"…
	var title: String {
		switch self {
		case .topLeading: "Top left"
		case .top: "Top"
		case .topTrailing: "Top right"
		case .leading: "Left"
		case .center: "Center"
		case .trailing: "Right"
		case .bottomLeading: "Bottom left"
		case .bottom: "Bottom"
		case .bottomTrailing: "Bottom right"
		}
	}

	var alignment: Alignment {
		switch self {
		case .topLeading: .topLeading
		case .top: .top
		case .topTrailing: .topTrailing
		case .leading: .leading
		case .center: .center
		case .trailing: .trailing
		case .bottomLeading: .bottomLeading
		case .bottom: .bottom
		case .bottomTrailing: .bottomTrailing
		}
	}
}

/// How a toggle looks. Switch is the default here (macOS's own default is a checkbox).
enum ToggleStyleOption: String, Codable, CaseIterable, Identifiable {
	case `switch`, checkbox, button
	var id: String { rawValue }
}

/// What a button shows: its title, its symbol, or both.
enum ButtonDisplay: String, Codable, CaseIterable, Identifiable {
	case title, icon, titleAndIcon
	var id: String { rawValue }
}

enum ButtonStyleOption: String, Codable, CaseIterable, Identifiable {
	case automatic, bordered, borderedProminent, borderless, plain, glass, glassProminent
	var id: String { rawValue }
	var title: String {
		switch self {
		case .automatic: "Automatic"
		case .bordered: "Bordered"
		case .borderedProminent: "Prominent"
		case .borderless: "Borderless"
		case .plain: "Plain"
		case .glass: "Glass"
		case .glassProminent: "Glass Prominent"
		}
	}
}

enum ControlSizeOption: String, Codable, CaseIterable, Identifiable {
	case mini, small, regular, large, extraLarge
	var id: String { rawValue }
	var title: String { self == .extraLarge ? "XL" : rawValue.prefix(1).uppercased() }
	var controlSize: ControlSize {
		switch self {
		case .mini: .mini
		case .small: .small
		case .regular: .regular
		case .large: .large
		case .extraLarge: .extraLarge
		}
	}
}

enum PickerStyleOption: String, Codable, CaseIterable, Identifiable {
	case menu, segmented, radioGroup
	var id: String { rawValue }
	var title: String { self == .radioGroup ? "Radio" : rawValue.capitalized }
}

enum DateComponentsOption: String, Codable, CaseIterable, Identifiable {
	case date, time, both
	var id: String { rawValue }
	var title: String { self == .both ? "Date & Time" : rawValue.capitalized }
}

enum ScrollAxisOption: String, Codable, CaseIterable, Identifiable {
	case vertical, horizontal
	var id: String { rawValue }
}

/// The outline an image is cut to.
enum ImageShape: String, Codable, CaseIterable, Identifiable {
	case roundedRect, circle, capsule
	var id: String { rawValue }
}

/// A stroke around a component (or around an image's shape).
struct BorderSettings: Codable, Equatable {
	var color = RGBA(r: 0.5, g: 0.5, b: 0.55)
	var width = 2.0
}

struct ShadowSettings: Codable, Equatable {
	var color = RGBA(r: 0, g: 0, b: 0, a: 0.3)
	var radius = 8.0
	var x = 0.0
	var y = 4.0
}

/// Color and focus adjustments for images. The defaults change nothing.
struct ImageAdjustments: Codable, Equatable {
	var grayscale = 0.0
	var saturation = 1.0
	var brightness = 0.0
	var contrast = 1.0
	var blur = 0.0

	var isIdentity: Bool { self == ImageAdjustments() }
}

/// How an SF Symbol uses color.
enum SymbolRendering: String, Codable, CaseIterable, Identifiable {
	/// One color for the whole symbol.
	case monochrome
	/// Shades of one color, one per layer of the symbol.
	case hierarchical
	/// A separate color for each layer.
	case palette
	/// The symbol's own built-in colors, where it has them.
	case multicolor

	var id: String { rawValue }
}
