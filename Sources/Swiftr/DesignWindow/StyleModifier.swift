import SwiftUI

/// Applies the shared style properties in the same order the code generator emits them.
struct StyleModifier: ViewModifier {
	let props: Props
	let kind: ComponentKind
	var fillsWindow = false

	func body(content: Content) -> some View {
		content
			.if(kind.usesControlSize && props.controlSize != .regular) {
				$0.controlSize(props.controlSize.controlSize)
			}
			// Bordered macOS buttons ignore a font set from outside; ButtonLabel sets it on the label.
			.if(kind.usesFont && kind != .button) {
				$0.font(.system(size: props.fontSize, weight: props.weight.fontWeight))
			}
			.if(props.foreground != nil) { $0.foregroundStyle(props.foreground?.color ?? .primary) }
			.if(kind.usesAccent && props.accent != nil) { $0.tint(props.accent?.color) }
			.frame(
				width: fillsWindow ? nil : props.width.map { CGFloat($0) },
				height: fillsWindow ? nil : props.height.map { CGFloat($0) },
				// An image's anchor decides which part stays visible when it's cropped.
				alignment: kind == .photo ? props.imageAnchor.alignment : .center
			)
			.frame(
				maxWidth: props.fillWidth || fillsWindow ? .infinity : nil,
				maxHeight: props.fillHeight || fillsWindow ? .infinity : nil
			)
			// Images crop to their frame (rounded by the corner radius) when filling it.
			.if(kind == .photo) { $0.clipShape(RoundedRectangle(cornerRadius: props.cornerRadius)) }
			.padding(props.padding)
			.if(props.background != nil) {
				$0.background(
					props.background?.color ?? .clear,
					in: RoundedRectangle(cornerRadius: props.cornerRadius))
			}
			// Buttons get glass through their button style instead (see `ButtonAppearance`).
			.modifier(
				GlassModifier(
					glass: kind == .button ? nil : props.glass, cornerRadius: props.cornerRadius)
			)
			.opacity(props.opacity)
	}
}

struct GlassModifier: ViewModifier {
	let glass: GlassSettings?
	let cornerRadius: Double

	func body(content: Content) -> some View {
		if let glass {
			switch glass.shape {
			case .roundedRect:
				content.glassEffect(glass.glass, in: RoundedRectangle(cornerRadius: cornerRadius))
			case .capsule:
				content.glassEffect(glass.glass, in: Capsule())
			case .circle:
				// Grow to a square the content fits inside, rather than a circle it spills out of.
				CircleFit { content }.glassEffect(glass.glass, in: Circle())
			}
		} else {
			content
		}
	}
}

extension GlassSettings {
	var glass: Glass {
		var g: Glass = variant == .clear ? .clear : .regular
		if let tint { g = g.tint(tint.color) }
		if interactive { g = g.interactive() }
		return g
	}
}

extension DateComponentsOption {
	var components: DatePickerComponents {
		switch self {
		case .date: .date
		case .time: .hourAndMinute
		case .both: [.date, .hourAndMinute]
		}
	}
}

extension View {
	@ViewBuilder
	func buttonStyle(option: ButtonStyleOption) -> some View {
		switch option {
		case .automatic: self
		case .bordered: buttonStyle(.bordered)
		case .borderedProminent: buttonStyle(.borderedProminent)
		case .borderless: buttonStyle(.borderless)
		case .plain: buttonStyle(.plain)
		case .glass: buttonStyle(.glass)
		case .glassProminent: buttonStyle(.glassProminent)
		}
	}

	@ViewBuilder
	func toggleStyle(option: ToggleStyleOption) -> some View {
		switch option {
		case .switch: toggleStyle(.switch)
		case .checkbox: toggleStyle(.checkbox)
		case .button: toggleStyle(.button)
		}
	}

	@ViewBuilder
	func pickerStyle(option: PickerStyleOption) -> some View {
		switch option {
		case .menu: pickerStyle(.menu)
		case .segmented: pickerStyle(.segmented)
		case .radioGroup: pickerStyle(.radioGroup)
		}
	}
}

/// Sizes to a square whose inscribed circle contains the content (its diagonal), content centered.
/// The generated code includes the same layout when it's used.
struct CircleFit: Layout {
	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let size = subviews.first?.sizeThatFits(.unspecified) ?? .zero
		let diameter = (size.width * size.width + size.height * size.height).squareRoot().rounded(
			.up)
		return CGSize(width: diameter, height: diameter)
	}

	func placeSubviews(
		in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
	) {
		subviews.first?.place(
			at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
	}
}
