import SwiftUI

/// Turns the project into a complete SwiftUI app (macOS 15+, or 26+ with Liquid Glass): an `App` with one `Window` scene
/// per designed window, followed by each window's view.
struct CodeGenerator {
	private let project: Project
	private var states: [String] = []
	private var usesOpenWindow = false
	private var usesDismiss = false
	private var usesCircleFit = false
	/// The window being generated, for its conditions.
	private var window: DesignWindow?
	/// `@State` names for this view's controls, assigned up front so conditions can refer to
	/// controls that come later in the view.
	private var stateNames: [UUID: String] = [:]
	private var usedNames: Set<String> = ["body", "openWindow", "dismiss"]

	private init(project: Project) { self.project = project }

	static func fileName(_ project: Project) -> String { "\(project.appName)App.swift" }

	static func generate(_ project: Project) -> String {
		var out = "import SwiftUI\n\n"
		if !project.images.isEmpty {
			// Image("name") needs these in the app's asset catalog.
			out += "// Images used: \(project.images.map(\.name).joined(separator: ", "))\n"
			out +=
				"// Add them to Assets.xcassets (Swiftr: File → Export Images to Asset Catalog…).\n\n"
		}
		out += "@main\nstruct \(project.appName)App: App {\n    var body: some Scene {\n"
		out += project.windows.enumerated().map { i, w in scene(w, isFirst: i == 0) }.joined(
			separator: "\n\n")
		out += "\n    }\n}\n"

		var usesCircleFit = false
		for window in project.windows {
			var generator = CodeGenerator(project: project)
			out += "\n" + generator.view(window)
			usesCircleFit = usesCircleFit || generator.usesCircleFit
		}
		if usesCircleFit { out += "\n" + circleFitSource }

		if let first = project.windows.first {
			out += "\n#Preview {\n    \(first.viewName)()\n}\n"
		}
		return out
	}

	// MARK: Scenes

	private static func scene(_ w: DesignWindow, isFirst: Bool) -> String {
		let s = w.settings
		var lines = [
			"Window(\(literal(s.title)), id: \(literal(w.sceneID))) {",
			"    \(w.viewName)()",
			"}",
			".defaultSize(width: \(number(s.width)), height: \(number(s.height)))",
		]
		switch s.titleBar {
		case .standard: break
		case .hidden: lines.append(".windowStyle(.hiddenTitleBar)")
		case .plain: lines.append(".windowStyle(.plain)")
		}
		if !s.resizable { lines.append(".windowResizability(.contentSize)") }
		if s.floating { lines.append(".windowLevel(.floating)") }
		// SwiftUI presents only the first scene at launch unless told otherwise.
		if isFirst && !s.opensAtLaunch { lines.append(".defaultLaunchBehavior(.suppressed)") }
		if !isFirst && s.opensAtLaunch { lines.append(".defaultLaunchBehavior(.presented)") }
		return lines.map { "        " + $0 }.joined(separator: "\n")
	}

	// MARK: Views

	private mutating func view(_ w: DesignWindow) -> String {
		window = w
		assignStateNames(w.root)
		var body = emit(w.root, level: 2, isRoot: true)
		// A fixed-size window takes its size from its content.
		if !w.settings.resizable {
			body +=
				"\n            .frame(width: \(Self.number(w.settings.width)), height: \(Self.number(w.settings.height)))"
		}

		var out = "struct \(w.viewName): View {\n"
		if usesOpenWindow { out += "    @Environment(\\.openWindow) private var openWindow\n" }
		if usesDismiss { out += "    @Environment(\\.dismiss) private var dismiss\n" }
		for state in states { out += "    \(state)\n" }
		if usesOpenWindow || usesDismiss || !states.isEmpty { out += "\n" }
		out += "    var body: some View {\n\(body)\n    }\n}\n"
		return out
	}

	/// The SwiftUI for one component, with any state or environment it uses declared above it.
	static func snippet(for node: Node, in project: Project) -> String {
		var generator = CodeGenerator(project: project)
		if let i = project.windowIndex(containing: node.id) {
			generator.window = project.windows[i]
			generator.assignStateNames(project.windows[i].root)
		}
		let body = generator.emit(node, level: 0)
		var declarations: [String] = []
		if generator.usesOpenWindow {
			declarations.append("@Environment(\\.openWindow) private var openWindow")
		}
		if generator.usesDismiss {
			declarations.append("@Environment(\\.dismiss) private var dismiss")
		}
		declarations += generator.states
		return declarations.isEmpty ? body : declarations.joined(separator: "\n") + "\n\n" + body
	}

	/// Liquid Glass needs macOS 26; everything else runs on macOS 15.
	static func minimumOS(_ project: Project) -> String {
		var usesGlass = false
		for w in project.windows {
			var root = w.root
			root.forEach { node in
				let p = node.props
				if p.glass != nil || p.glassContainer
					|| [.glass, .glassProminent].contains(p.buttonStyle)
				{
					usesGlass = true
				}
			}
		}
		return usesGlass ? "macOS 26" : "macOS 15"
	}

	/// A component's code, wrapped in `if … { }` when it has a condition.
	private mutating func emit(_ node: Node, level: Int, isRoot: Bool = false) -> String {
		guard !isRoot, let condition = window?.conditions.condition(for: node.id),
			let test = boolSwift(condition)
		else { return emitComponent(node, level: level, isRoot: isRoot) }
		let pad = String(repeating: "    ", count: level)
		return "\(pad)if \(test) {\n" + emitComponent(node, level: level + 1, isRoot: isRoot) + "\n\(pad)}"
	}

	private mutating func emitComponent(_ node: Node, level: Int, isRoot: Bool = false) -> String {
		let pad = String(repeating: "    ", count: level)
		let p = node.props
		// The root, and a lone container in the window, fill the window (as in the design windows).
		let fillsWindow = isRoot || project.fillsWindow(node.id)
		var head: String
		var mods: [String] = []

		/// Emits `open { children }`, one level deeper.
		func block(_ open: String, _ children: [Node], level: Int) -> String {
			let pad = String(repeating: "    ", count: level)
			if children.isEmpty { return open + " {}" }
			var lines: [String] = []
			for child in children { lines.append(emit(child, level: level + 1)) }
			return "\(open) {\n\(lines.joined(separator: "\n"))\n\(pad)}"
		}

		func stackOpen(_ name: String, kind: ComponentKind) -> String {
			var args: [String] = []
			if p.align != .center { args.append("alignment: .\(p.align.name(for: kind))") }
			args.append("spacing: \(Self.number(p.spacing))")
			return "\(name)(\(args.joined(separator: ", ")))"
		}

		switch node.kind {
		case .text:
			head = "Text(\(Self.literal(p.text)))"
		case .label:
			head = "Label(\(Self.literal(p.text)), systemImage: \(Self.literal(p.systemImage)))"
		case .button:
			let action = buttonAction(p.action)
			let title = Self.literal(p.text)
			let symbol = Self.literal(p.systemImage)
			let circle = p.glass?.shape == .circle && p.buttonDisplay != .icon
			// Bordered macOS buttons ignore a font set on the button, so a custom font goes on the label.
			let font = Self.fontModifier(p)
			// A button's bezel wraps its label, so filling the width means widening the label.
			if circle || font != nil || p.fillWidth {
				var label =
					p.buttonDisplay == .title
					? "Text(\(title))" : "Label(\(title), systemImage: \(symbol))"
				label += font ?? ""
				if p.fillWidth { label += ".frame(maxWidth: .infinity)" }
				if circle {
					// A circular button is only as wide as it is tall; square the label so the text fits.
					usesCircleFit = true
					label += ".circleFit()"
				}
				head =
					"Button {\n\(pad)    \(action)\n\(pad)} label: {\n\(pad)    \(label)\n\(pad)}"
			} else if p.buttonDisplay == .title {
				head = "Button(\(title)) {\n\(pad)    \(action)\n\(pad)}"
			} else {
				head = "Button(\(title), systemImage: \(symbol)) {\n\(pad)    \(action)\n\(pad)}"
			}
			switch p.buttonDisplay {
			case .title: break
			case .icon: mods.append(".labelStyle(.iconOnly)")
			case .titleAndIcon: mods.append(".labelStyle(.titleAndIcon)")
			}
			if let glass = p.glass {
				// Glass buttons use the glass button style and a border shape, not `.glassEffect`.
				mods.append(
					glass.variant == .clear
						? ".buttonStyle(.glass(.clear))" : ".buttonStyle(.glass)")
				switch glass.shape {
				case .roundedRect:
					mods.append(
						".buttonBorderShape(.roundedRectangle(radius: \(Self.number(p.cornerRadius))))"
					)
				case .capsule: mods.append(".buttonBorderShape(.capsule)")
				case .circle: mods.append(".buttonBorderShape(.circle)")
				}
				if let tint = glass.tint { mods.append(".tint(\(Self.color(tint)))") }
			} else if let style = Self.buttonStyle(p.buttonStyle) {
				mods.append(".buttonStyle(\(style))")
			}
		case .link:
			head =
				"Link(\(Self.literal(p.text)), destination: URL(string: \(Self.literal(p.url)))!)"
		case .textField:
			let name = newState(node, "text", type: "String", initial: "\"\"")
			head = "TextField(\(Self.literal(p.placeholder)), text: $\(name))"
		case .secureField:
			let name = newState(node, "password", type: "String", initial: "\"\"")
			head = "SecureField(\(Self.literal(p.placeholder)), text: $\(name))"
		case .textEditor:
			let name = newState(node, "text", type: "String", initial: "\"\"")
			head = "TextEditor(text: $\(name))"
		case .toggle:
			let name = newState(node, "isOn", type: "Bool", initial: p.isOn ? "true" : "false")
			head = "Toggle(\(Self.literal(p.text)), isOn: $\(name))"
			// A checkbox is the macOS default, so only the others need a style.
			switch p.toggleStyle {
			case .switch: mods.append(".toggleStyle(.switch)")
			case .checkbox: break
			case .button: mods.append(".toggleStyle(.button)")
			}
		case .slider:
			let name = newState(node, "value", type: "Double", initial: Self.number(p.value))
			head = "Slider(value: $\(name), in: 0...1)"
		case .stepper:
			let name = newState(node, "count", type: "Int", initial: String(Int(p.value)))
			let title = String(Self.literal(p.text).dropLast()) + ": \\(\(name))\""
			head = "Stepper(\(title), value: $\(name))"
		case .picker:
			let name = newState(node, "selection", type: "Int", initial: String(p.selectedIndex))
			let items = p.options.enumerated()
				.map { "\(pad)    Text(\(Self.literal($1))).tag(\($0))" }
				.joined(separator: "\n")
			head = "Picker(\(Self.literal(p.text)), selection: $\(name)) {\n\(items)\n\(pad)}"
			switch p.pickerStyle {
			case .menu: break
			case .segmented: mods.append(".pickerStyle(.segmented)")
			case .radioGroup: mods.append(".pickerStyle(.radioGroup)")
			}
		case .datePicker:
			let name = newState(node, "date", type: "Date", initial: "Date()")
			let components: String
			switch p.dateComponents {
			case .date: components = ".date"
			case .time: components = ".hourAndMinute"
			case .both: components = "[.date, .hourAndMinute]"
			}
			head =
				"DatePicker(\(Self.literal(p.text)), selection: $\(name), displayedComponents: \(components))"
		case .progress:
			head =
				p.indeterminate ? "ProgressView()" : "ProgressView(value: \(Self.number(p.value)))"
		case .image:
			head = "Image(systemName: \(Self.literal(p.systemImage)))"
		case .rectangle:
			head = "RoundedRectangle(cornerRadius: \(Self.number(p.cornerRadius)))"
			mods.append(".fill(\(Self.color(p.fill)))")
		case .circle, .capsule, .ellipse:
			head =
				node.kind == .circle
				? "Circle()" : node.kind == .capsule ? "Capsule()" : "Ellipse()"
			mods.append(".fill(\(Self.color(p.fill)))")
		case .divider:
			head = "Divider()"
		case .spacer:
			head = "Spacer()"
		case .vstack, .hstack, .zstack:
			let open =
				node.kind == .vstack
				? stackOpen("VStack", kind: .vstack)
				: node.kind == .hstack ? stackOpen("HStack", kind: .hstack) : "ZStack"
			if p.glassContainer {
				let inner = String(repeating: "    ", count: level + 1)
				head =
					"GlassEffectContainer(spacing: \(Self.number(p.spacing))) {\n\(inner)"
					+ block(open, node.children, level: level + 1) + "\n\(pad)}"
			} else {
				head = block(open, node.children, level: level)
			}
		case .scrollView:
			let inner = String(repeating: "    ", count: level + 1)
			let isVertical = p.scrollAxis == .vertical
			let stack =
				isVertical ? stackOpen("VStack", kind: .vstack) : stackOpen("HStack", kind: .hstack)
			head =
				(isVertical ? "ScrollView" : "ScrollView(.horizontal)") + " {\n\(inner)"
				+ block(stack, node.children, level: level + 1) + "\n\(pad)}"
		case .groupBox:
			let inner = String(repeating: "    ", count: level + 1)
			let open = p.text.isEmpty ? "GroupBox" : "GroupBox(\(Self.literal(p.text)))"
			head =
				"\(open) {\n\(inner)"
				+ block(stackOpen("VStack", kind: .vstack), node.children, level: level + 1)
				+ "\n\(pad)}"
		case .controlGroup:
			head = block("ControlGroup", node.children, level: level)
		case .menu:
			let items = block("Menu", node.children, level: level)
			head =
				items
				+ " label: {\n\(pad)    Label(\(Self.literal(p.text)), systemImage: \(Self.literal(p.systemImage)))\n\(pad)}"
		case .form:
			head = block("Form", node.children, level: level)
		case .section:
			head = block(
				p.text.isEmpty ? "Section" : "Section(\(Self.literal(p.text)))", node.children,
				level: level)
		case .disclosureGroup:
			let name = newState(node, "isExpanded", type: "Bool", initial: p.isOn ? "true" : "false")
			let inner = String(repeating: "    ", count: level + 1)
			head =
				"DisclosureGroup(\(Self.literal(p.text)), isExpanded: $\(name)) {\n\(inner)"
				+ block(stackOpen("VStack", kind: .vstack), node.children, level: level + 1)
				+ "\n\(pad)}"
		case .photo:
			if let asset = project.image(p.imageID) {
				head = "Image(\(Self.literal(asset.name)))"
				mods.append(".resizable()")
				if p.contentMode != .stretch {
					mods.append(".aspectRatio(contentMode: .\(p.contentMode.rawValue))")
				}
				// Adjustments that change something, in the same order as the design windows.
				let a = p.adjustments
				if a.grayscale != 0 { mods.append(".grayscale(\(Self.number(a.grayscale)))") }
				if a.saturation != 1 { mods.append(".saturation(\(Self.number(a.saturation)))") }
				if a.brightness != 0 { mods.append(".brightness(\(Self.number(a.brightness)))") }
				if a.contrast != 1 { mods.append(".contrast(\(Self.number(a.contrast)))") }
				if a.blur != 0 { mods.append(".blur(radius: \(Self.number(a.blur)))") }
			} else {
				head = "Image(systemName: \"photo\")"
			}
		case .tab, .pane:
			// A tab's content, or a split view column: a vertical stack (the Tab/column wrapper is
			// emitted by the parent).
			head = block(stackOpen("VStack", kind: .vstack), node.children, level: level)
		case .tabView:
			let name = newState(node, "tab", type: "Int", initial: String(p.selectedIndex))
			var tabs: [String] = []
			for (index, tab) in node.children.enumerated() {
				let tabPad = String(repeating: "    ", count: level + 1)
				tabs.append(
					"\(tabPad)Tab(\(Self.literal(tab.props.text)), systemImage: \(Self.literal(tab.props.systemImage)), value: \(index)) {\n"
						+ emit(tab, level: level + 2) + "\n\(tabPad)}")
			}
			head = "TabView(selection: $\(name)) {\n\(tabs.joined(separator: "\n"))\n\(pad)}"
		case .splitView:
			var columns: [String] = []
			for pane in node.children.prefix(3) { columns.append(emit(pane, level: level + 1)) }
			while columns.count < 2 { columns.append("\(pad)    EmptyView()") }
			head =
				columns.count == 3
				? "NavigationSplitView {\n\(columns[0])\n\(pad)} content: {\n\(columns[1])\n\(pad)} detail: {\n\(columns[2])\n\(pad)}"
				: "NavigationSplitView {\n\(columns[0])\n\(pad)} detail: {\n\(columns[1])\n\(pad)}"
		case .navigationStack:
			let inner = String(repeating: "    ", count: level + 1)
			head =
				"NavigationStack {\n\(inner)"
				+ block(stackOpen("VStack", kind: .vstack), node.children, level: level + 1)
				+ "\n\(pad)}"
		case .navigationLink:
			let inner = String(repeating: "    ", count: level + 1)
			head =
				"NavigationLink {\n\(inner)"
				+ block(stackOpen("VStack", kind: .vstack), node.children, level: level + 1)
				+ "\n\(pad)} label: {\n\(pad)    Text(\(Self.literal(p.text)))\n\(pad)}"
		}

		if let style = node.kind.variant(p.variant)?.code { mods.append(style) }

		// Shared style modifiers, in the same order the design windows apply them.
		if node.kind.usesControlSize && p.controlSize != .regular {
			mods.append(".controlSize(.\(p.controlSize.rawValue))")
		}
		if node.kind.usesFont && node.kind != .button, let font = Self.fontModifier(p) {
			mods.append(font)
		}
		if let fg = p.foreground {
			mods.append(".foregroundStyle(\(Self.color(fg)))")
		}
		if node.kind.usesAccent, let accent = p.accent {
			mods.append(".tint(\(Self.color(accent)))")
		}
		var fixed: [String] = []
		if !fillsWindow, let w = p.width { fixed.append("width: \(Self.number(w))") }
		if !fillsWindow, let h = p.height { fixed.append("height: \(Self.number(h))") }
		if node.kind == .photo, !fixed.isEmpty, p.imageAnchor != .center {
			fixed.append("alignment: .\(p.imageAnchor.rawValue)")
		}
		if !fixed.isEmpty { mods.append(".frame(\(fixed.joined(separator: ", ")))") }
		var flexible: [String] = []
		if p.fillWidth || fillsWindow { flexible.append("maxWidth: .infinity") }
		if p.fillHeight || fillsWindow { flexible.append("maxHeight: .infinity") }
		if !flexible.isEmpty { mods.append(".frame(\(flexible.joined(separator: ", ")))") }
		if node.kind == .photo {
			switch p.imageShape {
			case .roundedRect:
				mods.append(p.cornerRadius > 0 ? ".clipShape(.rect(cornerRadius: \(Self.number(p.cornerRadius))))" : ".clipped()")
			case .circle: mods.append(".clipShape(.circle)")
			case .capsule: mods.append(".clipShape(.capsule)")
			}
			// An image's border follows its shape.
			if let border = p.border { mods.append(Self.borderOverlay(border, shape: Self.imageShapeCode(p))) }
		}
		if p.padding > 0 { mods.append(".padding(\(Self.number(p.padding)))") }
		if let bg = p.background {
			mods.append(
				".background(\(Self.color(bg)), in: RoundedRectangle(cornerRadius: \(Self.number(p.cornerRadius))))"
			)
		}
		// Other components' borders go around their background.
		if node.kind != .photo, let border = p.border {
			mods.append(Self.borderOverlay(border, shape: "RoundedRectangle(cornerRadius: \(Self.number(p.cornerRadius)))"))
		}
		if let glass = p.glass, node.kind != .button {
			if glass.shape == .circle {
				usesCircleFit = true
				mods.append(".circleFit()")
			}
			mods.append(Self.glassEffect(glass, cornerRadius: p.cornerRadius))
		}
		if let shadow = p.shadow {
			mods.append(
				".shadow(color: \(Self.color(shadow.color)), radius: \(Self.number(shadow.radius)), x: \(Self.number(shadow.x)), y: \(Self.number(shadow.y)))"
			)
		}
		if p.opacity < 1 { mods.append(".opacity(\(Self.number(p.opacity)))") }

		// A layer name the user gave becomes a comment, so it's findable in the code.
		let comment = node.name.map { "\(pad)// \($0)\n" } ?? ""
		return comment + pad + head + mods.map { "\n\(pad)    \($0)" }.joined()
	}

	/// `.font(...)` for a custom size or weight, or nil for the default.
	private static func fontModifier(_ p: Props) -> String? {
		guard p.fontSize != 13 || p.weight != .regular else { return nil }
		let weight = p.weight == .regular ? "" : ", weight: .\(p.weight.rawValue)"
		return ".font(.system(size: \(number(p.fontSize))\(weight)))"
	}

	private static func imageShapeCode(_ p: Props) -> String {
		switch p.imageShape {
		case .roundedRect: "RoundedRectangle(cornerRadius: \(number(p.cornerRadius)))"
		case .circle: "Circle()"
		case .capsule: "Capsule()"
		}
	}

	private static func borderOverlay(_ border: BorderSettings, shape: String) -> String {
		".overlay { \(shape).strokeBorder(\(color(border.color)), lineWidth: \(number(border.width))) }"
	}

	private static func buttonStyle(_ option: ButtonStyleOption) -> String? {
		switch option {
		case .automatic: nil
		case .bordered: ".bordered"
		case .borderedProminent: ".borderedProminent"
		case .borderless: ".borderless"
		case .plain: ".plain"
		case .glass: ".glass"
		case .glassProminent: ".glassProminent"
		}
	}

	private static let circleFitSource = """
		/// Sizes to a square whose inscribed circle contains the content, so circular glass fits around it.
		struct CircleFit: Layout {
		    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		        let size = subviews.first?.sizeThatFits(.unspecified) ?? .zero
		        let diameter = (size.width * size.width + size.height * size.height).squareRoot().rounded(.up)
		        return CGSize(width: diameter, height: diameter)
		    }

		    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
		    }
		}

		extension View {
		    func circleFit() -> some View { CircleFit { self } }
		}

		"""

	private static func glassEffect(_ g: GlassSettings, cornerRadius: Double) -> String {
		var glass = g.variant == .clear ? ".clear" : ".regular"
		if let tint = g.tint { glass += ".tint(\(color(tint)))" }
		if g.interactive { glass += ".interactive()" }
		let shape: String
		switch g.shape {
		case .roundedRect: shape = ".rect(cornerRadius: \(number(cornerRadius)))"
		case .capsule: shape = ".capsule"
		case .circle: shape = ".circle"
		}
		return ".glassEffect(\(glass), in: \(shape))"
	}

	private mutating func buttonAction(_ action: ButtonAction?) -> String {
		switch action {
		case .openWindow(let id):
			guard let target = project.window(id) else { return "// TODO: action" }
			usesOpenWindow = true
			return "openWindow(id: \(Self.literal(target.sceneID)))"
		case .closeWindow:
			usesDismiss = true
			return "dismiss()"
		case nil:
			return "// TODO: action"
		}
	}

	private mutating func newState(_ node: Node, _ base: String, type: String, initial: String) -> String {
		let name = stateNames[node.id] ?? uniqueName(base)
		states.append("@State private var \(name): \(type) = \(initial)")
		return name
	}

	// MARK: State names

	private static let statefulDefaults: [ComponentKind: String] = [
		.textField: "text", .secureField: "password", .textEditor: "text", .toggle: "isOn",
		.slider: "value", .stepper: "count", .picker: "selection", .datePicker: "date",
		.tabView: "tab", .disclosureGroup: "isExpanded",
	]

	/// Names each stateful control from its variable name, layer name or title ("Dark mode" →
	/// `darkMode`), falling back to its kind ("isOn"), unique within the view.
	private mutating func assignStateNames(_ root: Node) {
		var root = root
		var order: [Node] = []
		root.forEach { order.append($0) }
		for node in order {
			guard let fallback = Self.statefulDefaults[node.kind] else { continue }
			let p = node.props
			let candidates = [p.variableName, node.name, p.text, p.placeholder]
			let base = candidates.lazy.compactMap { $0 }.map(Self.camelCase).first { !$0.isEmpty } ?? fallback
			stateNames[node.id] = uniqueName(base)
		}
	}

	private mutating func uniqueName(_ base: String) -> String {
		var name = base
		var n = 2
		while usedNames.contains(name) || Self.swiftKeywords.contains(name) {
			name = "\(base)\(n)"
			n += 1
		}
		usedNames.insert(name)
		return name
	}

	/// "Dark mode" → "darkMode", "2FA code" → "_2faCode".
	static func camelCase(_ text: String) -> String {
		let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
		guard let first = words.first else { return "" }
		var name = first.lowercased() + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
		if let c = name.first, c.isNumber { name = "_" + name }
		return name
	}

	private static let swiftKeywords: Set<String> = [
		"as", "break", "case", "catch", "class", "continue", "default", "defer", "do", "else", "enum",
		"extension", "false", "for", "func", "if", "import", "in", "init", "is", "let", "nil", "private",
		"protocol", "public", "repeat", "return", "self", "static", "struct", "super", "switch", "throw",
		"true", "try", "var", "where", "while", "some", "any", "View", "Text",
	]

	// MARK: Conditions

	private func valueType(_ e: ConditionExpr) -> ConditionValueType {
		switch e {
		case .control(let id): project.find(id)?.kind.conditionValueType ?? .bool
		case .constant(.bool): .bool
		case .constant(.number): .number
		case .constant(.text): .text
		default: .bool
		}
	}

	/// A condition as a Swift Bool expression, with the same meaning as Preview's evaluation.
	/// Nil when it refers to a control this view doesn't have.
	private func boolSwift(_ e: ConditionExpr) -> String? {
		guard let code = swift(e) else { return nil }
		switch valueType(e) {
		case .bool: return code
		case .number: return "\(code) != 0"
		case .text: return "!\(code).isEmpty"
		}
	}

	private func swift(_ e: ConditionExpr) -> String? {
		func grouped(_ e: ConditionExpr) -> String? {
			guard let code = boolSwift(e) else { return nil }
			switch e {
			case .and, .or: return "(\(code))"
			default: return code
			}
		}
		switch e {
		case .control(let id):
			return stateNames[id]
		case .constant(let v):
			switch v {
			case .bool(let b): return b ? "true" : "false"
			case .number(let n): return Self.number(n)
			case .text(let t): return Self.literal(t)
			}
		case .not(let inner):
			guard let code = grouped(inner) else { return nil }
			return code.contains(" ") && !code.hasPrefix("(") ? "!(\(code))" : "!\(code)"
		case .and(let a, let b):
			guard let l = grouped(a), let r = grouped(b) else { return nil }
			return "\(l) && \(r)"
		case .or(let a, let b):
			guard let l = grouped(a), let r = grouped(b) else { return nil }
			return "\(l) || \(r)"
		case .compare(let op, let a, let b):
			guard let l = swift(a) else { return nil }
			switch op {
			case .isEmpty: return "\(l).isEmpty"
			case .isNotEmpty: return "!\(l).isEmpty"
			case .contains:
				guard let b, let r = swift(b) else { return nil }
				return "\(l).localizedCaseInsensitiveContains(\(r))"
			default:
				guard let b, var r = swift(b) else { return nil }
				var left = l
				// Steppers and pickers are Int state; compare with fractions as Double.
				if case .control(let id) = a, [.stepper, .picker].contains(project.find(id)?.kind),
					case .constant(.number(let n)) = b, n != n.rounded()
				{
					left = "Double(\(l))"
				}
				if valueType(a) == .text, case .constant(let v) = b { r = Self.literal(v.text) }
				let symbol = [
					CompareOp.equal: "==", .notEqual: "!=", .less: "<", .lessOrEqual: "<=",
					.greater: ">", .greaterOrEqual: ">=",
				][op] ?? "=="
				return "\(left) \(symbol) \(r)"
			}
		}
	}

	// MARK: Formatting

	static func literal(_ s: String) -> String {
		let escaped =
			s
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
			.replacingOccurrences(of: "\n", with: "\\n")
		return "\"\(escaped)\""
	}

	static func number(_ d: Double) -> String {
		let rounded = (d * 1000).rounded() / 1000
		if rounded == rounded.rounded() && abs(rounded) < 1e12 { return String(Int(rounded)) }
		return String(rounded)
	}

	static func color(_ c: RGBA) -> String {
		var s = "Color(red: \(number(c.r)), green: \(number(c.g)), blue: \(number(c.b)))"
		if c.a < 1 { s += ".opacity(\(number(c.a)))" }
		return s
	}
}
