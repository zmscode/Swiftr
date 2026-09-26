import SwiftUI

/// A W/H field: a number when fixed, "Hug"/"Fill" otherwise, with the mode in a menu.
struct SizeField: View {
	let model: DesignModel
	let id: UUID
	let axis: Axis
	let fallback: Double

	private var path: WritableKeyPath<Props, Double?> { axis == .horizontal ? \.width : \.height }
	private var props: Props { model.project.find(id)?.props ?? Props() }

	var body: some View {
		let mode = props.sizeMode(axis)
		HStack(spacing: 6) {
			PanelScrubLabel(
				label: .letter(axis == .horizontal ? "W" : "H"), value: number, range: 0...4000)
			if mode == .fixed {
				TextField("", value: number, format: .number.precision(.fractionLength(0...1)))
					.textFieldStyle(.plain)
					.font(PanelStyle.font.monospacedDigit())
			} else {
				Text(mode == .hug ? "Hug" : "Fill").foregroundStyle(.secondary)
				Spacer(minLength: 0)
			}
			Menu {
				ForEach(SizeMode.allCases) { m in
					Button {
						setMode(m)
					} label: {
						if m == mode {
							Label(title(m), systemImage: "checkmark")
						} else {
							Text(title(m))
						}
					}
				}
			} label: {
				Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
					.foregroundStyle(.secondary)
			}
			.menuStyle(.button)
			.buttonStyle(.plain)
			.menuIndicator(.hidden)
			.fixedSize()
		}
		.fieldChrome()
		.help(
			"\(axis == .horizontal ? "Width" : "Height"): Hug fits the content, Fixed sets a size, Fill takes the space available. Drag the letter to adjust"
		)
	}

	private func title(_ m: SizeMode) -> String {
		switch m {
		case .fixed: "Fixed \(axis == .horizontal ? "width" : "height")"
		case .hug: "Hug contents"
		case .fill: "Fill container"
		}
	}

	/// Scrubbing or typing a number switches the axis to fixed. An image with its aspect ratio
	/// locked resizes the other axis to match.
	private var number: Binding<Double> {
		Binding(
			get: { props[keyPath: path] ?? fallback },
			set: { value in
				let ratio = aspectRatio
				model.updateProps(id, key: \Props.width) { p in
					p[keyPath: path] = value
					if axis == .horizontal { p.fillWidth = false } else { p.fillHeight = false }
					if let ratio {
						if axis == .horizontal {
							p.height = (value / ratio).rounded()
						} else {
							p.width = (value * ratio).rounded()
						}
						p.fillWidth = false
						p.fillHeight = false
					}
				}
			}
		)
	}

	/// Width ÷ height to keep, for images with Keep Aspect Ratio on.
	private var aspectRatio: Double? {
		guard let node = model.project.find(id), node.kind == .photo, node.props.lockAspect else {
			return nil
		}
		if let w = node.props.width, let h = node.props.height, h > 0 { return w / h }
		return model.naturalSize(ofImageIn: id).map { $0.width / $0.height }
	}

	private func setMode(_ m: SizeMode) {
		model.updateProps(id, key: path) { $0.setSizeMode(m, axis, fallback: fallback) }
	}
}
