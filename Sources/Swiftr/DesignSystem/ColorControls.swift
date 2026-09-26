import SwiftUI

/// Swatch (opens the color picker), editable hex, opacity, and optional remove button.
struct PanelColorRow: View {
	@Binding var color: RGBA
	var onRemove: (() -> Void)? = nil
	@State private var showPicker = false
	@State private var hexDraft = ""
	@FocusState private var hexFocused: Bool

	var body: some View {
		HStack(spacing: PanelStyle.gutter) {
			HStack(spacing: 7) {
				Button {
					showPicker.toggle()
				} label: {
					Swatch(color: color).frame(width: 16, height: 16)
				}
				.buttonStyle(.plain)
				.help("Choose a color")
				.popover(isPresented: $showPicker, arrowEdge: .leading) {
					ColorPopover(color: $color)
				}
				TextField("", text: $hexDraft)
					.textFieldStyle(.plain)
					.font(PanelStyle.font.monospaced())
					.focused($hexFocused)
					.onSubmit { commitHex() }
					.help("Hex color, e.g. FF8800")
					.onChange(of: hexFocused) { _, focused in if !focused { commitHex() } }
			}
			.fieldChrome(focused: hexFocused)

			PanelPercentField(
				label: .icon("circle.lefthalf.filled"), value: $color.a, help: "Opacity"
			)
			.frame(width: 74)

			if let onRemove { PanelIconButton(symbol: "minus", help: "Remove this color", action: onRemove) }
		}
		.onAppear { hexDraft = String(color.hex.dropFirst()) }
		.onChange(of: color) { _, c in if !hexFocused { hexDraft = String(c.hex.dropFirst()) } }
	}

	private func commitHex() {
		if let parsed = RGBA(hex: hexDraft, alpha: color.a) { color = parsed }
		hexDraft = String(color.hex.dropFirst())
	}
}

/// A color chip with a checkerboard behind it so transparency is visible.
struct Swatch: View {
	let color: RGBA
	var body: some View {
		ZStack {
			Checkerboard()
			RoundedRectangle(cornerRadius: 3).fill(color.color)
		}
		.clipShape(RoundedRectangle(cornerRadius: 3))
		.overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.15)))
	}
}

struct Checkerboard: View {
	var body: some View {
		Canvas { ctx, size in
			let s: CGFloat = 4
			ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
			for row in 0..<Int(ceil(size.height / s)) {
				for col in 0..<Int(ceil(size.width / s)) where (row + col).isMultiple(of: 2) {
					ctx.fill(
						Path(CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)),
						with: .color(Color(white: 0.8)))
				}
			}
		}
	}
}

extension RGBA {
	/// Parses "RRGGBB" or "#RRGGBB" (and 3-digit "RGB").
	init?(hex: String, alpha: Double = 1) {
		var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
		if s.hasPrefix("#") { s.removeFirst() }
		if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
		guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
		self.init(
			r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255,
			b: Double(v & 0xFF) / 255, a: alpha)
	}
}
