import SwiftUI

/// The bare SwiftUI view for a node, before shared style modifiers. `live` makes controls
/// interactive with their own state (Preview mode); otherwise they show their initial values.
struct NodeContent<Children: View>: View {
	let node: Node
	let windowID: UUID
	let live: Bool
	/// One child, with editing behavior where the parent allows it (tabs, split view columns).
	let child: (Node) -> AnyView
	@ViewBuilder let children: (Axis?) -> Children
	@Environment(DesignModel.self) private var model

	var body: some View {
		let p = node.props
		switch node.kind {
		case .text:
			Text(p.text)
		case .label:
			Label(p.text, systemImage: p.systemImage)
		case .button:
			Button {
				if live { model.perform(p.action, from: windowID) }
			} label: {
				ButtonLabel(props: p)
			}
			.modifier(ButtonAppearance(props: p.themed(model.project.theme)))
		case .link:
			Link(p.text, destination: URL(string: p.url) ?? URL(string: "https://www.apple.com")!)
		// In Preview, control values live in the model so conditions can react to them; while
		// editing, controls show their initial values.
		case .textField:
			TextField(p.placeholder, text: controlValue(.text("")).asText)
		case .secureField:
			SecureField(p.placeholder, text: controlValue(.text("")).asText)
		case .textEditor:
			TextEditor(text: controlValue(.text("")).asText)
		case .toggle:
			Toggle(p.text, isOn: controlValue(.bool(p.isOn)).asBool).toggleStyle(
				option: p.toggleStyle)
		case .slider:
			Group {
				if let step = p.sliderStep, step > 0 {
					Slider(
						value: controlValue(.number(p.value)).asNumber, in: p.sliderRange,
						step: step)
				} else {
					Slider(value: controlValue(.number(p.value)).asNumber, in: p.sliderRange)
				}
			}
			.frame(minWidth: 100)
		case .stepper:
			let count = controlValue(.number(Double(Int(p.value)))).asInt
			Stepper("\(p.text): \(count.wrappedValue)", value: count)
		case .picker:
			Picker(p.text, selection: controlValue(.number(Double(p.selectedIndex))).asInt) {
				ForEach(p.options.indices, id: \.self) { i in Text(p.options[i]).tag(i) }
			}
			.pickerStyle(option: p.pickerStyle)
		case .datePicker:
			LiveState(Date()) { date in
				DatePicker(
					p.text, selection: date, displayedComponents: p.dateComponents.components)
			}
			.id(live)
		case .progress:
			if p.indeterminate {
				ProgressView()
			} else {
				ProgressView(value: p.value)
			}
		case .image:
			SymbolImage(props: p)
		case .rectangle:
			RoundedRectangle(cornerRadius: p.cornerRadius).fill(p.fill.color)
		case .circle:
			Circle().fill(p.fill.color)
		case .capsule:
			Capsule().fill(p.fill.color)
		case .ellipse:
			Ellipse().fill(p.fill.color)
		case .divider:
			Divider()
		case .spacer:
			Spacer(minLength: 0)
				.frame(minWidth: live ? 0 : 8, minHeight: live ? 0 : 8)
		case .vstack:
			GlassContainerIf(p.glassContainer, spacing: p.spacing) {
				VStack(alignment: p.align.horizontal, spacing: p.spacing) { children(.vertical) }
			}
		case .hstack:
			GlassContainerIf(p.glassContainer, spacing: p.spacing) {
				HStack(alignment: p.align.vertical, spacing: p.spacing) { children(.horizontal) }
			}
		case .zstack:
			GlassContainerIf(p.glassContainer, spacing: p.spacing) {
				ZStack { children(nil) }
			}
		case .scrollView:
			ScrollView(p.scrollAxis == .vertical ? .vertical : .horizontal) {
				if p.scrollAxis == .vertical {
					VStack(alignment: p.align.horizontal, spacing: p.spacing) {
						children(.vertical)
					}
				} else {
					HStack(alignment: p.align.vertical, spacing: p.spacing) {
						children(.horizontal)
					}
				}
			}
		case .groupBox:
			GroupBox(p.text) {
				VStack(alignment: p.align.horizontal, spacing: p.spacing) { children(.vertical) }
			}
		case .controlGroup:
			// Control groups and menus restyle their children into segments and menu items, which
			// editing overlays would break, so their children render plainly (edit them via Layers).
			ControlGroup { plainChildren }
		case .menu:
			Menu {
				plainChildren
			} label: {
				Label(p.text, systemImage: p.systemImage)
			}
		case .form:
			Form { children(.vertical) }
		case .section:
			Section(p.text) { children(.vertical) }
		case .disclosureGroup:
			LiveState(p.isOn) { expanded in
				DisclosureGroup(p.text, isExpanded: expanded) {
					VStack(alignment: p.align.horizontal, spacing: p.spacing) {
						children(.vertical)
					}
				}
			}
			.id("\(live)\(p.isOn)")
		case .photo:
			if let image = model.nsImage(p.imageID) {
				Group {
					switch p.contentMode {
					case .stretch: Image(nsImage: image).resizable()
					case .fit: Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
					case .fill: Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
					}
				}
				.modifier(ImageAdjustmentsModifier(adjustments: p.adjustments))
			} else {
				ZStack {
					Rectangle().fill(Color.secondary.opacity(0.15))
					VStack(spacing: 4) {
						Image(systemName: "photo").font(.title2)
						if !live { Text("Double-click or drop an image").font(.caption) }
					}
					.foregroundStyle(.secondary)
				}
			}
		case .tabView:
			if live {
				LiveState(p.selectedIndex) { tabView(selection: $0) }
					.id(p.selectedIndex)
			} else {
				tabView(selection: editingTab)
			}
		case .tab, .pane:
			VStack(alignment: p.align.horizontal, spacing: p.spacing) { children(.vertical) }
		case .splitView:
			let panes = node.children
			if panes.count >= 3 {
				NavigationSplitView {
					child(panes[0])
				} content: {
					child(panes[1])
				} detail: {
					child(panes[2])
				}
			} else {
				NavigationSplitView {
					if let first = panes.first { child(first) }
				} detail: {
					if panes.count > 1 { child(panes[1]) }
				}
			}
		case .navigationStack:
			NavigationStack {
				VStack(alignment: p.align.horizontal, spacing: p.spacing) { children(.vertical) }
			}
		case .navigationLink:
			if live {
				NavigationLink {
					VStack(alignment: p.align.horizontal, spacing: p.spacing) { plainChildren }
				} label: {
					Text(p.text)
				}
			} else {
				// The destination only appears once pushed, in Preview; edit it through Layers.
				Button {
				} label: {
					HStack(spacing: 6) {
						Text(p.text)
						Image(systemName: "chevron.right").font(.caption.weight(.semibold))
					}
				}
			}
		}
	}

	private func tabView(selection: Binding<Int>) -> some View {
		TabView(selection: selection) {
			ForEach(Array(node.children.enumerated()), id: \.element.id) { index, tab in
				child(tab)
					.tabItem { Label(tab.props.text, systemImage: tab.props.systemImage) }
					.tag(index)
			}
		}
	}

	/// While editing, show the tab holding the selection; clicking a tab sets the initially selected tab.
	private var editingTab: Binding<Int> {
		Binding(
			get: {
				if let selection = model.selection,
					let index = node.children.firstIndex(where: { $0.find(selection) != nil })
				{
					return index
				}
				return min(node.props.selectedIndex, max(node.children.count - 1, 0))
			},
			set: { index in
				model.updateProps(node.id, key: \Props.selectedIndex) { $0.selectedIndex = index }
			}
		)
	}

	/// A control's value: shared live state in Preview, fixed at its initial value while editing.
	private func controlValue(_ initial: ConditionValue) -> Binding<ConditionValue> {
		live ? model.liveBinding(node.id, initial: initial) : .constant(initial)
	}

	private var plainChildren: some View {
		ForEach(node.children) { PlainNode(node: $0, windowID: windowID, live: live) }
	}
}

/// A component and its children rendered without editing behavior.
struct PlainNode: View {
	@Environment(DesignModel.self) private var model
	let node: Node
	let windowID: UUID
	let live: Bool

	var body: some View {
		NodeContent(
			node: node, windowID: windowID, live: live,
			child: { AnyView(PlainNode(node: $0, windowID: windowID, live: live)) }
		) { _ in
			ForEach(node.children) { PlainNode(node: $0, windowID: windowID, live: live) }
		}
		.modifier(VariantModifier(kind: node.kind, variant: node.props.variant))
		.modifier(StyleModifier(props: node.props.themed(model.project.theme), kind: node.kind))
	}
}

/// A button's style: Liquid Glass (with its border shape and tint) when the button has glass,
/// otherwise the chosen button style.
struct ButtonAppearance: ViewModifier {
	let props: Props

	func body(content: Content) -> some View {
		if let glass = props.glass {
			content
				.modifier(GlassButtonStyle(variant: glass.variant))
				.modifier(BorderShape(shape: glass.shape, cornerRadius: props.cornerRadius))
				.if(glass.tint != nil) { $0.tint(glass.tint?.color) }
		} else {
			content.buttonStyle(option: props.buttonStyle)
		}
	}
}

private struct GlassButtonStyle: ViewModifier {
	let variant: GlassVariant
	func body(content: Content) -> some View {
		switch variant {
		case .regular: content.buttonStyle(.glass)
		case .clear: content.buttonStyle(.glass(.clear))
		}
	}
}

private struct BorderShape: ViewModifier {
	let shape: GlassShape
	let cornerRadius: Double
	func body(content: Content) -> some View {
		switch shape {
		case .roundedRect: content.buttonBorderShape(.roundedRectangle(radius: cornerRadius))
		case .capsule: content.buttonBorderShape(.capsule)
		case .circle: content.buttonBorderShape(.circle)
		}
	}
}

/// Holds a control's value: real `@State` so it responds to input. The owner resets it with
/// `.id(...)` when switching modes or when the design's initial value changes.
struct LiveState<Value, Content: View>: View {
	@State private var value: Value
	let content: (Binding<Value>) -> Content

	init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
		_value = State(initialValue: initial)
		self.content = content
	}

	var body: some View { content($value) }
}

struct GlassContainerIf<Content: View>: View {
	let enabled: Bool
	let spacing: Double
	@ViewBuilder let content: Content

	init(_ enabled: Bool, spacing: Double, @ViewBuilder content: () -> Content) {
		self.enabled = enabled
		self.spacing = spacing
		self.content = content()
	}

	var body: some View {
		if enabled {
			GlassEffectContainer(spacing: spacing) { content }
		} else {
			content
		}
	}
}

/// A button's label: title, symbol (the title stays as its accessibility label), or both. The font
/// goes on the label because bordered macOS buttons ignore a font set on the button itself.
struct ButtonLabel: View {
	let props: Props

	var body: some View {
		content
			.font(.system(size: props.fontSize, weight: props.weight.fontWeight))
			// A button's bezel wraps its label, so filling the width means widening the label.
			.frame(maxWidth: props.fillWidth ? .infinity : nil)
	}

	@ViewBuilder
	private var content: some View {
		let label = Label(props.text, systemImage: props.systemImage)
		switch props.buttonDisplay {
		case .title:
			// A circular button is only as wide as it is tall; square the label so the text fits.
			if props.glass?.shape == .circle {
				CircleFit { Text(props.text) }
			} else {
				Text(props.text)
			}
		case .icon:
			label.labelStyle(.iconOnly)
		case .titleAndIcon:
			if props.glass?.shape == .circle {
				CircleFit { label.labelStyle(.titleAndIcon) }
			} else {
				label.labelStyle(.titleAndIcon)
			}
		}
	}
}

extension Binding where Value == ConditionValue {
	var asBool: Binding<Bool> {
		Binding<Bool>(get: { wrappedValue.bool }, set: { wrappedValue = .bool($0) })
	}
	var asNumber: Binding<Double> {
		Binding<Double>(get: { wrappedValue.number }, set: { wrappedValue = .number($0) })
	}
	var asInt: Binding<Int> {
		Binding<Int>(get: { Int(wrappedValue.number) }, set: { wrappedValue = .number(Double($0)) })
	}
	var asText: Binding<String> {
		Binding<String>(get: { wrappedValue.text }, set: { wrappedValue = .text($0) })
	}
}

/// An SF Symbol with its rendering mode, and its layer colors when rendered as a palette.
struct SymbolImage: View {
	let props: Props

	var body: some View {
		let image = Image(systemName: props.systemImage).symbolRenderingMode(
			props.symbolRendering.mode)
		if props.symbolRendering == .palette {
			let primary = props.foreground?.color ?? .primary
			let secondary = props.symbolSecondary?.color ?? .secondary
			if let tertiary = props.symbolTertiary {
				image.foregroundStyle(primary, secondary, tertiary.color)
			} else {
				image.foregroundStyle(primary, secondary)
			}
		} else {
			image
		}
	}
}

extension SymbolRendering {
	var mode: SymbolRenderingMode {
		switch self {
		case .monochrome: .monochrome
		case .hierarchical: .hierarchical
		case .palette: .palette
		case .multicolor: .multicolor
		}
	}
}
