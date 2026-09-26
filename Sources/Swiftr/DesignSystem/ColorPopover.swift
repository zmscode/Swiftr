import AppKit
import ColorKit
import SwiftUI

/// The color picker, built on ColorKit: saturation/brightness pad, hue and alpha sliders,
/// plus hex/RGB fields and the colors already used in the project.
struct ColorPopover: View {
	static let sliderHeight: CGFloat = 14
	static let pickerHeight: CGFloat = 230

	@Binding var color: RGBA
	@Environment(DesignModel.self) private var model
	@State private var token = ColorToken(hue: 0.6, saturation: 0.8, brightness: 0.9)
	@State private var loaded = false

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HSBColorPicker($token, sliderHeight: Self.sliderHeight)
				.frame(height: Self.pickerHeight)
				.overlay { HSBJumpLayer(token: $token) }

			AlphaSlider($token, sliderHeight: Self.sliderHeight)
				.frame(height: Self.sliderHeight)
				.overlay {
					JumpArea { x, _ in token = token.update(alpha: Double(x)) }
				}
				.padding(.horizontal, Self.sliderHeight / 2)

			HStack(spacing: PanelStyle.gutter) {
				Swatch(color: color).frame(width: 26, height: 26)
				PanelCommitField(
					value: Binding(
						get: { String(color.hex.dropFirst()) },
						set: { if let c = RGBA(hex: $0, alpha: color.a) { setColor(c) } }
					))
				PanelPercentField(
					label: .letter("A"),
					value: Binding(
						get: { color.a },
						set: { a in
							var c = color
							c.a = a
							setColor(c)
						}
					)
				)
				.frame(width: 74)
			}

			HStack(spacing: 6) {
				ForEach(Array(zip(["R", "G", "B"], [\RGBA.r, \RGBA.g, \RGBA.b])), id: \.0) {
					letter, path in
					PanelNumberField(
						label: .letter(letter),
						value: Binding(
							get: { (color[keyPath: path] * 255).rounded() },
							set: { v in
								var c = color
								c[keyPath: path] = v / 255
								setColor(c)
							}
						), range: 0...255)
				}
			}

			let swatches = documentColors
			if !swatches.isEmpty {
				VStack(alignment: .leading, spacing: 6) {
					PanelCaption("In this project")
					LazyVGrid(
						columns: Array(repeating: GridItem(.fixed(20), spacing: 6), count: 9),
						spacing: 6
					) {
						ForEach(swatches, id: \.hex) { c in
							Button {
								setColor(c)
							} label: {
								Swatch(color: c).frame(width: 20, height: 20)
							}
							.buttonStyle(.plain)
							.help(c.hex)
						}
					}
				}
			}
		}
		.padding(14)
		.frame(width: 260)
		.onAppear {
			token = ColorToken(color)
			loaded = true
		}
		.onChange(of: token.color) { _, _ in
			// The token drives the pad and sliders; write its color out after the first load.
			guard loaded else { return }
			let new = RGBA(token.color)
			if new != color { color = new }
		}
	}

	/// Sets the color from the fields or swatches, and moves the pad and sliders to match.
	private func setColor(_ c: RGBA) {
		color = c
		token = ColorToken(c)
	}

	private var documentColors: [RGBA] {
		var seen = Set<String>()
		var result: [RGBA] = []
		// The project's scheme first, then colours already used in the design.
		let theme = model.project.theme
		for c in [theme.accent].compactMap({ $0 }) + theme.palette where seen.insert(c.hex).inserted
		{
			result.append(c)
		}
		for w in model.project.windows {
			var root = w.root
			root.forEach { node in
				let p = node.props
				let colors = [
					p.foreground, p.background, p.glass?.tint, node.kind.isShape ? p.fill : nil,
				]
				for case let c? in colors where seen.insert(c.hex).inserted {
					result.append(c)
				}
			}
		}
		return Array(result.prefix(18))
	}
}

extension ColorToken {
	init(_ c: RGBA) {
		let ns = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
		self.init(
			hue: Double(ns.hueComponent), saturation: Double(ns.saturationComponent),
			brightness: Double(ns.brightnessComponent), opacity: c.a)
	}
}

/// ColorKit's pad and sliders only move when their handle is dragged. These layers sit on top and
/// jump the value to wherever you click, then follow the drag.
///
/// `HSBColorPicker` lays out as a VStack (spacing 30) of the saturation/brightness pad and a hue
/// slider `sliderHeight` tall, inset by half its height on each side; the mapping below mirrors
/// ColorKit's own (pad: 0.01...1 on both axes, measured from the top-left).
private struct HSBJumpLayer: View {
	@Binding var token: ColorToken
	@State private var draggingHue: Bool?

	var body: some View {
		GeometryReader { geo in
			let slider = ColorPopover.sliderHeight
			let padHeight = geo.size.height - 30 - slider
			Color.clear
				.contentShape(Rectangle())
				.gesture(
					DragGesture(minimumDistance: 0)
						.onChanged { drag in
							// Decide pad or hue slider from where the drag started, then stick with it.
							let hue = draggingHue ?? (drag.startLocation.y > padHeight + 15)
							draggingHue = hue
							if hue {
								let x = (drag.location.x - slider / 2) / (geo.size.width - slider)
								token = token.update(hue: Double(x.clamped(to: 0...1)))
							} else {
								let x = (drag.location.x / geo.size.width).clamped(to: 0...1)
								let y = (drag.location.y / padHeight).clamped(to: 0...1)
								token = token.update(saturation: Double(0.01 + x * 0.99))
								token = token.update(brightness: Double(0.01 + y * 0.99))
							}
						}
						.onEnded { _ in draggingHue = nil }
				)
		}
	}
}

/// A full-size area reporting the pointer's position as fractions of its size while pressed.
private struct JumpArea: View {
	let onChange: (CGFloat, CGFloat) -> Void

	var body: some View {
		GeometryReader { geo in
			Color.clear
				.contentShape(Rectangle())
				.gesture(
					DragGesture(minimumDistance: 0)
						.onChanged { drag in
							onChange(
								(drag.location.x / geo.size.width).clamped(to: 0...1),
								(drag.location.y / geo.size.height).clamped(to: 0...1))
						}
				)
		}
	}
}
