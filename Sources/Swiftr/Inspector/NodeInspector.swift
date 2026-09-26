import SwiftUI

/// Properties of the selected component. Only sections that apply to its kind are shown.
struct NodeInspector: View {
	@Environment(\.panelTheme) private var panelTheme
	let model: DesignModel
	let node: Node
	let window: DesignWindow

	private var isRoot: Bool { node.id == window.root.id }
	private var id: UUID { node.id }
	private var kind: ComponentKind { node.kind }
	private var props: Props { node.props }

	private func bind<T: Equatable>(_ path: WritableKeyPath<Props, T>) -> Binding<T> {
		model.propBinding(id, path)
	}

	private func win<T: Equatable>(_ path: WritableKeyPath<WindowSettings, T>) -> Binding<T> {
		model.windowBinding(window.id, path)
	}

	var body: some View {
		VStack(spacing: 0) {
			header
			ScrollView {
				VStack(spacing: 0) {
					if isRoot { windowSection }
					if hasContent { contentSection }
					if kind == .image { symbolSection }
					if hasStyle { styleSection }
					if kind.isContainer && kind != .menu { layoutSection }
					if kind.hasSize { sizeSection }
					if kind == .photo { imageSection }
					appearanceSection
					if !addItems.isEmpty {
						PanelSection("Add") { PanelAddBar(items: addItems) }
					}
					if hasColors { colorsSection }
					if hasEffects { effectsSection }
					if !isRoot { ConditionSection(model: model, node: node) }
					codeSection
				}
				.padding(.bottom, 16)
			}
		}
	}

	// MARK: Header

	private var header: some View {
		InspectorHeader(
			icon: isRoot ? "macwindow" : kind.symbol,
			tint: isRoot ? .secondary : panelTheme.tint(kind),
			name: isRoot
				? win(\.title)
				: Binding(get: { node.name ?? "" }, set: { model.renameNode(id, to: $0) }),
			placeholder: isRoot ? "Window title" : node.summary,
			subtitle: isRoot
				? "Window · \(window.viewName)"
				: model.editableSelection.count > 1
					? "\(model.editableSelection.count) selected · editing this one"
					: kind.displayName
		) {
			PanelIconButton(
				symbol: "plus.square.on.square",
				help: isRoot ? "Duplicate window" : "Duplicate (⌘D)"
			) {
				model.duplicateSelection()
			}
			PanelIconButton(symbol: "trash", help: isRoot ? "Delete window" : "Delete (⌫)") {
				if isRoot { model.deleteWindow(window.id) } else { model.deleteSelection() }
			}
		}
	}

	// MARK: Window

	private var windowSection: some View {
		PanelSection("Window") {
			PanelCaptioned("Size") {
				PanelGrid {
					PanelNumberField(
						label: .letter("W"), value: win(\.width), range: 120...4000, help: "Width")
				} b: {
					PanelNumberField(
						label: .letter("H"), value: win(\.height), range: 80...4000, help: "Height")
				}
			}
			PanelCaptioned("Title bar") {
				PanelSegmented(
					selection: win(\.titleBar),
					items: [
						(.standard, .icon("macwindow", "Standard title bar")),
						(.hidden, .icon("rectangle.topthird.inset.filled", "Hidden title bar")),
						(.plain, .icon("rectangle", "No window chrome")),
					])
			}
			VStack(alignment: .leading, spacing: 5) {
				PanelCheckbox(
					title: "Resizable", isOn: win(\.resizable),
					help:
						"Let people resize the window. Off makes it a fixed size (.windowResizability(.contentSize))"
				)
				PanelCheckbox(
					title: "Float above other windows", isOn: win(\.floating),
					help: "Applied in Preview mode, so it doesn't cover the panels while editing")
				PanelCheckbox(
					title: "Open at launch", isOn: win(\.opensAtLaunch),
					help: "Open this window when the app starts (.defaultLaunchBehavior)")
			}
			PanelCaptioned("View name") {
				PanelCommitField(
					placeholder: "View name", value: model.viewNameBinding(window.id),
					help: "The name of this window's SwiftUI view struct. Press Return to apply")
			}
		}
	}

	// MARK: Content

	private var hasContent: Bool {
		kind.hasTitle || kind.hasPlaceholder || kind.usesSymbol
			|| [
				.button, .slider, .stepper, .progress, .toggle, .picker, .datePicker, .scrollView,
				.disclosureGroup, .tabView, .splitView, .link,
			].contains(kind)
	}

	private var contentSection: some View {
		PanelSection("Content") {
			if kind.hasTitle {
				PanelTextField(
					placeholder: kind == .text ? "Text" : "Title", text: bind(\.text),
					multiline: kind == .text,
					help: kind == .button && props.buttonDisplay == .icon
						? "Title (read by VoiceOver for an icon-only button)" : nil)
			}
			if kind.hasDetail {
				PanelTextField(
					placeholder: kind == .labeledContent ? "Value" : "Description",
					text: bind(\.detail), multiline: kind == .unavailable,
					help: kind == .labeledContent
						? "The value shown beside the title" : "A line of text under the title")
			}
			if kind.hasPlaceholder {
				PanelTextField(
					placeholder: "Placeholder", text: bind(\.placeholder),
					help: "Hint text shown while the field is empty")
			}
			if kind == .button {
				PanelCaptioned("Shows") {
					PanelSegmented(
						selection: bind(\.buttonDisplay),
						items: [
							(.title, .icon("textformat", "Title only")),
							(
								.icon,
								.icon(
									"star", "Icon only (the title becomes its accessibility label)")
							),
							(.titleAndIcon, .icon("text.badge.star", "Title and icon")),
						])
				}
			}
			if kind.usesSymbol || (kind == .button && props.buttonDisplay != .title) {
				SymbolField(name: bind(\.systemImage))
			}
			if kind == .button {
				PanelCaptioned("Action") {
					PanelMenu(
						label: .icon("cursorarrow.click"), selection: bind(\.action),
						options: actionOptions,
						help: "What the button does when clicked (try it in Preview)")
				}
			}
			if kind == .link {
				PanelTextField(
					placeholder: "URL", text: bind(\.url), monospaced: true,
					help: "The web address the link opens")
			}
			if kind == .toggle {
				PanelCheckbox(
					title: "Initially on", isOn: bind(\.isOn),
					help: "Whether the toggle starts switched on")
			}
			if kind == .disclosureGroup {
				PanelCheckbox(
					title: "Initially expanded", isOn: bind(\.isOn),
					help: "Whether the group starts open")
			}
			if kind == .slider {
				PanelCaptioned("Value") {
					PanelNumberField(
						label: .icon("slider.horizontal.below.rectangle"), value: bind(\.value),
						range: props.sliderRange,
						step: (props.sliderRange.upperBound - props.sliderRange.lowerBound) / 100,
						help: "Initial value")
				}
				PanelCaptioned("Range") {
					PanelGrid {
						PanelNumberField(
							label: .letter("Min"), value: bind(\.sliderMin),
							range: -1_000_000...1_000_000, help: "Minimum")
					} b: {
						PanelNumberField(
							label: .letter("Max"), value: bind(\.sliderMax),
							range: -1_000_000...1_000_000, help: "Maximum")
					}
				}
				PanelCaptioned("Step (adds tick marks)") {
					PanelNumberField(
						label: .icon("stairs"),
						value: Binding(
							get: { props.sliderStep ?? 0 },
							set: { bind(\.sliderStep).wrappedValue = $0 > 0 ? $0 : nil }),
						range: 0...1_000_000,
						help:
							"0 slides smoothly; a step snaps to it and shows a tick mark at each step"
					)
					.frame(maxWidth: 120)
				}
			}
			if kind == .stepper {
				PanelNumberField(
					label: .letter("Value"), value: bind(\.value), range: -10_000...10_000)
			}
			if kind == .progress {
				PanelCheckbox(
					title: "Indeterminate", isOn: bind(\.indeterminate),
					help: "Show activity without a value (a spinner), for work of unknown length")
				if !props.indeterminate {
					PanelPercentField(label: .letter("Value"), value: bind(\.value))
				}
			}
			if kind == .gauge {
				PanelPercentField(label: .icon("gauge.with.dots.needle.33percent"), value: bind(\.value), help: "How full the gauge is")
			}
			if kind == .colorPicker {
				PanelCaptioned("Starts as") {
					PanelColorRow(color: bind(\.fill))
				}
			}
			if kind == .picker { pickerOptions }
			if kind == .datePicker {
				PanelCaptioned("Shows") {
					PanelSegmented(
						selection: bind(\.dateComponents),
						items: DateComponentsOption.allCases.map { ($0, .text($0.title)) })
				}
			}
			if kind == .scrollView {
				PanelCaptioned("Scrolls") {
					PanelSegmented(
						selection: bind(\.scrollAxis),
						items: [
							(.vertical, .icon("arrow.up.and.down", "Vertically")),
							(.horizontal, .icon("arrow.left.and.right", "Horizontally")),
						])
				}
			}
			if kind == .tabView {
				PanelTextButton(
					title: "Add Tab", symbol: "plus", help: "Add another tab to the end"
				) { model.addTab(to: id) }
			}
			if kind == .splitView {
				PanelSegmented(
					selection: Binding(
						get: { min(max(node.children.count, 2), 3) },
						set: { model.setColumnCount(id, to: $0) }),
					items: [(2, .text("2 Columns")), (3, .text("3 Columns"))])
			}
		}
	}

	private var actionOptions: [(value: ButtonAction?, title: String)] {
		var options: [(value: ButtonAction?, title: String)] = [
			(nil, "No action"), (.closeWindow, "Close this window"),
		]
		for other in model.project.windows where other.id != window.id {
			options.append((.openWindow(other.id), "Open “\(other.settings.title)”"))
		}
		return options
	}

	@ViewBuilder
	private var pickerOptions: some View {
		PanelCaptioned("Options") {
			VStack(spacing: 4) {
				ForEach(props.options.indices, id: \.self) { i in
					HStack(spacing: 6) {
						Image(
							systemName: i == props.selectedIndex
								? "largecircle.fill.circle" : "circle"
						)
						.foregroundStyle(i == props.selectedIndex ? panelTheme.accent : .secondary)
						.onTapGesture { bind(\.selectedIndex).wrappedValue = i }
						.help("Initially selected")
						PanelTextField(
							text: Binding(
								get: { props.options.indices.contains(i) ? props.options[i] : "" },
								set: { value in
									model.updateProps(id, key: \Props.options) {
										if $0.options.indices.contains(i) { $0.options[i] = value }
									}
								}
							))
						PanelIconButton(symbol: "minus", help: "Remove option") {
							model.updateProps(id, key: \Props.selectedIndex) { p in
								guard p.options.count > 1 else { return }
								p.options.remove(at: i)
								p.selectedIndex = min(p.selectedIndex, p.options.count - 1)
							}
						}
					}
				}
			}
		}
		PanelTextButton(
			title: "Add option", symbol: "plus", help: "Add another choice to the picker"
		) {
			model.updateProps(id, key: \Props.selectedIndex) {
				$0.options.append("Option \($0.options.count + 1)")
			}
		}
	}

	// MARK: Style

	private var hasStyle: Bool {
		!kind.variants.isEmpty || kind.usesControlSize
			|| [.button, .toggle, .picker].contains(kind)
	}

	private var styleSection: some View {
		PanelSection("Style") {
			if kind == .button {
				if props.glass == nil {
					PanelMenu(
						label: .icon("paintbrush"), selection: bind(\.buttonStyle),
						options: ButtonStyleOption.allCases.map { ($0, $0.title) },
						help: "The button's style (.buttonStyle)")
				} else {
					PanelCaption("Glass style, set in Effects → Glass.")
				}
			}
			if kind == .toggle {
				PanelSegmented(
					selection: bind(\.toggleStyle),
					items: [
						(.switch, .icon("switch.2", "Switch")),
						(.checkbox, .icon("checkmark.square", "Checkbox")),
						(.button, .icon("button.horizontal", "Button")),
					])
			}
			if kind == .picker {
				PanelSegmented(
					selection: bind(\.pickerStyle),
					items: PickerStyleOption.allCases.map { ($0, .text($0.title)) })
			}
			if !kind.variants.isEmpty {
				let variants = kind.variants
				let current = Binding(
					get: { kind.variant(props.variant)?.id ?? "" },
					set: { bind(\.variant).wrappedValue = $0 == variants.first?.id ? nil : $0 })
				if variants.count <= 3 {
					PanelSegmented(
						selection: current, items: variants.map { ($0.id, .text($0.title)) })
				} else {
					PanelMenu(
						label: .icon("paintbrush"), selection: current,
						options: variants.map { ($0.id, $0.title) },
						help: "The component's SwiftUI style")
				}
			}
			if kind.usesControlSize {
				PanelCaptioned("Size") {
					PanelSegmented(
						selection: bind(\.controlSize),
						items: ControlSizeOption.allCases.map {
							(
								$0,
								PanelSegmentLabel(
									text: $0.title, help: "\($0.rawValue) control size")
							)
						})
				}
			}
		}
	}

	// MARK: Layout

	private var layoutSection: some View {
		PanelSection("Layout") {
			if [.vstack, .hstack, .zstack].contains(kind) {
				PanelSegmented(
					selection: Binding(get: { kind }, set: { model.setKind(id, to: $0) }),
					items: [
						(.vstack, .icon("arrow.down", "Vertical (VStack)")),
						(.hstack, .icon("arrow.right", "Horizontal (HStack)")),
						(.zstack, .icon("square.3.layers.3d", "Overlapping (ZStack)")),
					])
			}
			if kind.usesStackLayout {
				PanelSegmented(
					selection: bind(\.align),
					items: StackAlign.allCases.map { a in
						(a, .icon(alignSymbol(a), "Align \(a.name(for: alignKind))"))
					})
				PanelGrid {
					PanelNumberField(
						label: .icon(isHorizontal ? "arrow.left.and.right" : "arrow.up.and.down"),
						value: bind(\.spacing), range: 0...500, help: "Gap between items")
				} b: {
					paddingField
				}
			} else {
				paddingField
			}
			if [.vstack, .hstack, .zstack].contains(kind) {
				PanelCheckbox(
					title: "Glass container", isOn: bind(\.glassContainer),
					help:
						"Wraps children in a GlassEffectContainer so their glass blends and morphs together"
				)
			}
		}
	}

	private var paddingField: some View {
		PanelNumberField(
			label: .icon("square.dashed"), value: bind(\.padding), range: 0...500, help: "Padding")
	}

	private var isHorizontal: Bool {
		kind == .hstack || (kind == .scrollView && props.scrollAxis == .horizontal)
	}

	/// Alignment is vertical for horizontal layouts and horizontal otherwise.
	private var alignKind: ComponentKind { isHorizontal ? .hstack : .vstack }

	private func alignSymbol(_ a: StackAlign) -> String {
		switch (isHorizontal, a) {
		case (true, .start): "align.vertical.top"
		case (true, .center): "align.vertical.center"
		case (true, .end): "align.vertical.bottom"
		case (false, .start): "align.horizontal.left"
		case (false, .center): "align.horizontal.center"
		case (false, .end): "align.horizontal.right"
		}
	}

	// MARK: Size

	private var sizeSection: some View {
		PanelSection("Size") {
			if model.project.fillsWindow(id) {
				Label("Fills the window", systemImage: "arrow.up.left.and.arrow.down.right")
					.foregroundStyle(.secondary)
			} else {
				PanelCaptioned("Dimensions") {
					PanelGrid {
						SizeField(model: model, id: id, axis: .horizontal, fallback: 100)
					} b: {
						SizeField(model: model, id: id, axis: .vertical, fallback: 44)
					}
				}
			}
			if kind == .photo {
				HStack {
					PanelCheckbox(
						title: "Keep aspect ratio", isOn: bind(\.lockAspect),
						help: "Keep the image's proportions when resizing it")
					Spacer()
					PanelTextButton(
						title: "Original Size", symbol: "arrow.uturn.backward",
						help: "Reset to the image's own pixel size"
					) {
						model.resetImageSize(id)
					}
				}
			}
			if !kind.isContainer {
				paddingField.frame(maxWidth: 120, alignment: .leading)
			}
		}
	}

	// MARK: Image

	private var imageSection: some View {
		PanelSection("Image") {
			HStack(spacing: 8) {
				Group {
					if let image = model.nsImage(props.imageID) {
						Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
					} else {
						Image(systemName: "photo").foregroundStyle(.secondary)
					}
				}
				.frame(width: 52, height: 52)
				.background(Color.primary.opacity(0.06))
				.clipShape(RoundedRectangle(cornerRadius: 6))
				VStack(alignment: .leading, spacing: 4) {
					PanelMenu(
						selection: bind(\.imageID),
						options: [(nil, "No image")]
							+ model.project.images.map { ($0.id, $0.name) },
						help: "Choose one of the project's images"
					)
					PanelTextButton(
						title: "Choose File…", symbol: "folder",
						help: "Add an image file to the project and show it here"
					) {
						model.chooseImage(for: id)
					}
				}
			}
			PanelCaptioned("Shape") {
				PanelSegmented(
					selection: bind(\.imageShape),
					items: [
						(
							.roundedRect,
							.icon("rectangle", "Rounded rectangle (uses corner radius)")
						),
						(.circle, .icon("circle", "Circle")),
						(.capsule, .icon("capsule", "Capsule")),
					])
			}
			PanelCaptioned("Mode") {
				PanelSegmented(
					selection: bind(\.contentMode),
					items: [
						(.fit, PanelSegmentLabel(text: "Fit", help: "Whole image visible")),
						(
							.fill,
							PanelSegmentLabel(
								text: "Fill", help: "Fills the frame, cropping the overflow")
						),
						(
							.stretch,
							PanelSegmentLabel(
								text: "Stretch", help: "Distorts to the frame's shape")
						),
					])
			}
			if props.contentMode != .stretch {
				PanelCaptioned(
					props.contentMode == .fill ? "Crop anchor" : "Position",
					help: props.contentMode == .fill
						? "Which part of the image stays visible when Fill crops it"
						: "Where the image sits in its frame"
				) {
					AnchorGrid(selection: bind(\.imageAnchor))
				}
			}
			adjustmentsRow
		}
	}

	// MARK: Symbol

	private var symbolSection: some View {
		PanelSection("Symbol") {
			PanelCaptioned("Size", help: "The symbol's point size and weight (.font(.system(size:weight:)))") {
				PanelGrid {
					PanelNumberField(
						label: .icon("arrow.up.left.and.arrow.down.right"), value: bind(\.fontSize),
						range: 6...512, unit: "pt", help: "Point size")
				} b: {
					PanelMenu(
						selection: bind(\.weight),
						options: FontWeight.allCases.map { ($0, $0.rawValue.capitalized) },
						help: "Weight (thin to black)")
				}
				PanelSegmented(
					selection: Binding(
						get: { Self.symbolSizes.contains(props.fontSize) ? props.fontSize : -1 },
						set: { if $0 > 0 { bind(\.fontSize).wrappedValue = $0 } }),
					items: Self.symbolSizes.map { size in
						(size, PanelSegmentLabel(text: CodeGenerator.number(size), help: "\(CodeGenerator.number(size)) pt"))
					})
			}
			PanelCaptioned("Rendering", help: "How the symbol uses color (.symbolRenderingMode)") {
				PanelSegmented(
					selection: bind(\.symbolRendering),
					items: [
						(
							.monochrome,
							PanelSegmentLabel(text: "Mono", help: "One color for the whole symbol")
						),
						(
							.hierarchical,
							PanelSegmentLabel(
								text: "Layers",
								help: "Shades of the color, one per layer of the symbol")
						),
						(
							.palette,
							PanelSegmentLabel(
								text: "Palette", help: "A separate color for each layer")
						),
						(
							.multicolor,
							PanelSegmentLabel(
								text: "Multi", help: "The symbol's own colors, where it has them")
						),
					])
			}
			symbolColor(
				props.symbolRendering == .palette ? "Primary" : "Color", \.foreground,
				fallback: .blue,
				help: "The symbol's color (.foregroundStyle)")
			if props.symbolRendering == .palette {
				symbolColor(
					"Secondary", \.symbolSecondary, fallback: RGBA(r: 0.55, g: 0.55, b: 0.6),
					help: "The second layer's color")
				symbolColor(
					"Tertiary", \.symbolTertiary, fallback: RGBA(r: 0.8, g: 0.8, b: 0.85),
					help: "The third layer's color (for symbols with three layers)")
			}
			if props.symbolRendering == .multicolor {
				PanelCaption("Parts with built-in colors keep them; the rest use the color above.")
			}
		}
	}

	/// An optional symbol color: a row with − once set, or a button to add it.
	@ViewBuilder
	private func symbolColor(
		_ title: String, _ path: WritableKeyPath<Props, RGBA?>, fallback: RGBA, help: String
	) -> some View {
		if let color = props[keyPath: path] {
			PanelCaptioned(title, help: help) {
				PanelColorRow(
					color: Binding(get: { color }, set: { bind(path).wrappedValue = $0 }),
					onRemove: { bind(path).wrappedValue = nil })
			}
		} else {
			PanelTextButton(title: "Add \(title.lowercased()) color", symbol: "plus", help: help) {
				bind(path).wrappedValue = fallback
			}
		}
	}

	// MARK: Effects

	private var adjustmentsRow: some View {
		let a = props.adjustments
		return PanelFlyoutRow(
			icon: "camera.filters", title: "Adjustments",
			summary: a.isIdentity ? "None" : "\(a.changedCount) changed",
			help: "Grayscale, saturation, brightness, contrast and blur"
		) {
			FlyoutField("Grayscale", icon: "circle.lefthalf.filled.righthalf.striped.horizontal") {
				PanelNumberField(label: .icon("arrow.left.and.right"), value: adjust(\.grayscale, scale: 100), range: 0...100, unit: "%")
			}
			FlyoutField("Saturation", icon: "drop") {
				PanelNumberField(label: .icon("arrow.left.and.right"), value: adjust(\.saturation, scale: 100), range: 0...300, unit: "%")
			}
			FlyoutField("Brightness", icon: "sun.max") {
				PanelNumberField(label: .icon("arrow.left.and.right"), value: adjust(\.brightness, scale: 100), range: -100...100, unit: "%")
			}
			FlyoutField("Contrast", icon: "circle.righthalf.filled") {
				PanelNumberField(label: .icon("arrow.left.and.right"), value: adjust(\.contrast, scale: 100), range: 0...300, unit: "%")
			}
			FlyoutField("Blur", icon: "aqi.medium") {
				PanelNumberField(label: .icon("arrow.left.and.right"), value: adjust(\.blur, scale: 1), range: 0...50, unit: "pt")
			}
			PanelTextButton(
				title: "Reset", symbol: "arrow.counterclockwise", help: "Undo all adjustments"
			) {
				bind(\.adjustments).wrappedValue = ImageAdjustments()
			}
			.disabled(a.isIdentity)
		}
	}

	/// An image adjustment shown scaled (e.g. 0...1 as a percentage).
	private func adjust(_ path: WritableKeyPath<ImageAdjustments, Double>, scale: Double)
		-> Binding<Double>
	{
		Binding(
			get: { (props.adjustments[keyPath: path] * scale).rounded() },
			set: { value in
				model.updateProps(id, key: \Props.adjustments) {
					$0.adjustments[keyPath: path] = value / scale
				}
			}
		)
	}

	// MARK: Colors and effects

	private var showsForeground: Bool { kind.supportsForeground && kind != .image }

	private var hasColors: Bool {
		kind.isShape || (kind.usesAccent && props.accent != nil)
			|| (showsForeground && props.foreground != nil)
			|| (kind.supportsBackground && props.background != nil)
	}

	private var colorsSection: some View {
		PanelSection("Colors") {
			if kind.isShape {
				colorRow("Fill", icon: "paintbrush.fill", color: bind(\.fill), onRemove: nil)
			}
			if kind.usesAccent { optionalColorRow("Accent", icon: "switch.2", \.accent) }
			// A symbol's color lives in its Symbol section.
			if showsForeground { optionalColorRow("Foreground", icon: "character", \.foreground) }
			if kind.supportsBackground {
				optionalColorRow("Background", icon: "rectangle.fill", \.background)
			}
		}
	}

	private func colorRow(
		_ title: String, icon: String, color: Binding<RGBA>, onRemove: (() -> Void)?
	) -> some View {
		HStack(spacing: 6) {
			Image(systemName: icon)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.frame(width: 16)
				.help(PanelSection<EmptyView>.descriptions[title] ?? title)
			PanelColorRow(color: color, onRemove: onRemove)
		}
	}

	@ViewBuilder
	private func optionalColorRow(
		_ title: String, icon: String, _ path: WritableKeyPath<Props, RGBA?>
	) -> some View {
		if let color = props[keyPath: path] {
			colorRow(
				title, icon: icon,
				color: Binding(get: { color }, set: { bind(path).wrappedValue = $0 }),
				onRemove: { bind(path).wrappedValue = nil })
		}
	}

	private var hasEffects: Bool {
		kind.supportsBorderAndShadow && (props.border != nil || props.shadow != nil)
			|| kind.supportsGlass && props.glass != nil
	}

	private var effectsSection: some View {
		PanelSection("Effects") {
			if let border = props.border, kind.supportsBorderAndShadow {
				PanelFlyoutRow(
					icon: "square.dashed", title: "Border",
					summary: "\(CodeGenerator.number(border.width)) pt", swatch: border.color,
					onRemove: { bind(\.border).wrappedValue = nil }
				) {
					borderEditor(border)
				}
			}
			if let shadow = props.shadow, kind.supportsBorderAndShadow {
				PanelFlyoutRow(
					icon: "shadow", title: "Shadow",
					summary:
						"blur \(CodeGenerator.number(shadow.radius)) · \(CodeGenerator.number(shadow.x)), \(CodeGenerator.number(shadow.y))",
					swatch: shadow.color,
					onRemove: { bind(\.shadow).wrappedValue = nil }
				) {
					shadowEditor(shadow)
				}
			}
			if let glass = props.glass, kind.supportsGlass {
				PanelFlyoutRow(
					icon: "drop", title: "Glass",
					summary: glassSummary(glass),
					swatch: glass.resolved(model.project.theme).tint,
					help: PanelSection<EmptyView>.descriptions["Liquid Glass"],
					onRemove: { bind(\.glass).wrappedValue = nil }
				) {
					glassEditor(glass)
				}
			}
		}
	}

	private func glassSummary(_ glass: GlassSettings) -> String {
		let look = glass.followsTheme ? "Theme" : glass.variant == .clear ? "Clear" : "Regular"
		return "\(look) · \(glass.shape.title)"
	}

	/// Optional colors, effects and a condition that aren't set yet, as one row of buttons.
	private var addItems: [PanelAddBar.Item] {
		var items: [PanelAddBar.Item] = []
		func add(_ title: String, _ icon: String, _ action: @escaping () -> Void) {
			items.append(PanelAddBar.Item(icon: icon, title: title, action: action))
		}
		if kind.usesAccent && props.accent == nil {
			add("Accent", "switch.2") { bind(\.accent).wrappedValue = .blue }
		}
		if showsForeground && props.foreground == nil {
			add("Foreground", "character") { bind(\.foreground).wrappedValue = .black }
		}
		if kind.supportsBackground && props.background == nil {
			add("Background", "rectangle.fill") { bind(\.background).wrappedValue = .lightGray }
		}
		if kind.supportsBorderAndShadow && props.border == nil {
			add("Border", "square.dashed") { bind(\.border).wrappedValue = BorderSettings() }
		}
		if kind.supportsBorderAndShadow && props.shadow == nil {
			add("Shadow", "shadow") { bind(\.shadow).wrappedValue = ShadowSettings() }
		}
		if kind.supportsGlass && props.glass == nil {
			add("Glass", "drop") { bind(\.glass).wrappedValue = GlassSettings() }
		}
		if !isRoot, model.condition(for: id) == nil,
			let source = model.conditionSources(for: id).first
		{
			add("Condition", "questionmark.diamond") {
				model.setCondition(model.defaultCondition(source: source), for: id)
			}
		}
		return items
	}

	@ViewBuilder
	private func borderEditor(_ border: BorderSettings) -> some View {
		FlyoutField("Color", icon: "paintpalette") {
			PanelColorRow(color: optional(\.border, \.color, current: border))
		}
		FlyoutField("Width", icon: "lineweight") {
			PanelNumberField(
				label: .icon("arrow.left.and.right"), value: optional(\.border, \.width, current: border), range: 0...50, unit: "pt")
		}
	}

	@ViewBuilder
	private func shadowEditor(_ shadow: ShadowSettings) -> some View {
		FlyoutField("Color", icon: "paintpalette") {
			PanelColorRow(color: optional(\.shadow, \.color, current: shadow))
		}
		FlyoutField("Blur", icon: "aqi.medium") {
			PanelNumberField(
				label: .icon("arrow.left.and.right"), value: optional(\.shadow, \.radius, current: shadow), range: 0...200, unit: "pt")
		}
		FlyoutField("Offset", icon: "arrow.down.right") {
			PanelGrid {
				PanelNumberField(
					label: .letter("X"), value: optional(\.shadow, \.x, current: shadow),
					range: -200...200, help: "Horizontal offset")
			} b: {
				PanelNumberField(
					label: .letter("Y"), value: optional(\.shadow, \.y, current: shadow),
					range: -200...200, help: "Vertical offset")
			}
		}
	}

	/// A binding into one field of an optional property group (border, shadow) that's present.
	private func optional<Group: Equatable, Value: Equatable>(
		_ group: WritableKeyPath<Props, Group?>, _ field: WritableKeyPath<Group, Value>,
		current: Group
	) -> Binding<Value> {
		Binding(
			get: { props[keyPath: group]?[keyPath: field] ?? current[keyPath: field] },
			set: { value in
				model.updateProps(id, key: group) { $0[keyPath: group]?[keyPath: field] = value }
			}
		)
	}

	// MARK: Appearance

	/// Corner radius shows where something is rounded: a rectangle, an image, a background, or
	/// rectangular glass.
	private var usesCornerRadius: Bool {
		kind == .rectangle || kind == .photo || props.background != nil
			|| props.glass?.shape == .roundedRect
	}

	private var appearanceSection: some View {
		PanelSection("Appearance") {
			PanelGrid {
				PanelPercentField(
					label: .icon("circle.lefthalf.filled"), value: bind(\.opacity), help: "Opacity")
			} b: {
				if usesCornerRadius {
					PanelNumberField(
						label: .icon("button.roundedtop.horizontal"), value: bind(\.cornerRadius),
						range: 0...500, help: "Corner radius")
				} else {
					Color.clear.frame(height: PanelStyle.fieldHeight)
				}
			}
			// A symbol's size is in its Symbol section.
			if kind.usesFont && kind != .image { typography }
		}
	}

	private static let symbolSizes: [Double] = [16, 24, 32, 48, 64, 96]

	private var typography: some View {
		PanelGrid {
				PanelNumberField(
					label: .icon("textformat.size"), value: bind(\.fontSize), range: 6...300,
					help: "Font size")
			} b: {
				PanelMenu(
					selection: bind(\.weight),
					options: FontWeight.allCases.map { ($0, $0.rawValue.capitalized) },
					help: "Font weight")
			}
	}

	// MARK: Glass

	@ViewBuilder
	private func glassEditor(_ glass: GlassSettings) -> some View {
		// "Theme" follows the project theme; Regular and Clear are this component's own look.
		FlyoutField("Look", icon: "drop") {
			PanelSegmented(
				selection: Binding(
					get: { glass.followsTheme ? nil : glass.variant },
					set: { look in
						model.updateProps(id, key: \Props.glass) {
							$0.glass?.followsTheme = look == nil
							if let look { $0.glass?.variant = look }
						}
					}),
				items: [
					(nil, PanelSegmentLabel(text: "Theme", help: "The project theme's glass (Theme tab)")),
					(.regular, PanelSegmentLabel(text: "Regular", help: "Regular glass")),
					(.clear, PanelSegmentLabel(text: "Clear", help: "Clear glass")),
				])
		}
		FlyoutField("Shape", icon: "square.on.circle") {
			PanelSegmented(
				selection: glassBinding(\.shape, glass),
				items: [
					(.roundedRect, .icon("rectangle", "Rounded rectangle (uses corner radius)")),
					(.capsule, .icon("capsule", "Capsule")),
					(.circle, .icon("circle", "Circle")),
				])
		}
		if glass.followsTheme {
			PanelCaption("Theme glass: \(model.project.theme.glass.summary).")
		} else {
			FlyoutField("Tint", icon: "eyedropper") {
				if let tint = glass.tint {
					PanelColorRow(
						color: Binding(
							get: { tint }, set: { glassBinding(\.tint, glass).wrappedValue = $0 }),
						onRemove: { glassBinding(\.tint, glass).wrappedValue = nil })
				} else {
					PanelTextButton(title: "Add tint", symbol: "plus", help: "Color the glass") {
						glassBinding(\.tint, glass).wrappedValue = RGBA(r: 0.2, g: 0.5, b: 1, a: 0.6)
					}
				}
			}
			if kind != .button {
				PanelCheckbox(
					title: "Interactive", isOn: glassBinding(\.interactive, glass),
					help: "Reacts to touch and pointer, like system glass controls")
			}
		}
		if kind == .button {
			PanelCaption("Buttons use the glass button style; the shape sets their border.")
		}
	}

	private func glassBinding<T: Equatable>(
		_ path: WritableKeyPath<GlassSettings, T>, _ current: GlassSettings
	)
		-> Binding<T>
	{
		Binding(
			get: { props.glass?[keyPath: path] ?? current[keyPath: path] },
			set: { value in
				model.updateProps(id, key: \Props.glass) { $0.glass?[keyPath: path] = value }
			}
		)
	}

	// MARK: Code

	private var codeSection: some View {
		PanelSection("Code", collapsedByDefault: true) {
			CodeSnippetView(code: CodeGenerator.snippet(for: node, in: model.project))
		}
	}
}

/// A 3×3 grid for picking an anchor point.
struct AnchorGrid: View {
	@Environment(\.panelTheme) private var panelTheme
	@Binding var selection: AnchorOption

	var body: some View {
		let rows: [[AnchorOption]] = [
			[.topLeading, .top, .topTrailing], [.leading, .center, .trailing],
			[.bottomLeading, .bottom, .bottomTrailing],
		]
		VStack(spacing: 2) {
			ForEach(0..<3, id: \.self) { r in
				HStack(spacing: 2) {
					ForEach(rows[r]) { anchor in
						Button {
							selection = anchor
						} label: {
							Circle()
								.fill(
									anchor == selection
										? panelTheme.accent : Color.primary.opacity(0.25)
								)
								.frame(
									width: anchor == selection ? 7 : 4,
									height: anchor == selection ? 7 : 4
								)
								.frame(width: 18, height: 14)
								.contentShape(Rectangle())
						}
						.buttonStyle(.plain)
						.help(anchor.title)
					}
				}
			}
		}
		.padding(4)
		.background(RoundedRectangle(cornerRadius: PanelStyle.radius).fill(PanelStyle.fieldFill))
	}
}
