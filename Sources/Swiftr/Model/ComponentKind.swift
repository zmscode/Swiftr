import SwiftUI

enum ComponentKind: String, Codable, CaseIterable, Identifiable {
	case text, label, button, link
	case textField, secureField, textEditor
	case toggle, slider, stepper, picker, datePicker, progress
	case image, rectangle, circle, capsule, ellipse, divider
	case vstack, hstack, zstack, scrollView, groupBox, spacer
	case controlGroup, menu, form, section, disclosureGroup
	case photo
	case tabView, tab, splitView, pane, navigationStack, navigationLink

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .text: "Text"
		case .label: "Label"
		case .button: "Button"
		case .link: "Link"
		case .textField: "Text Field"
		case .secureField: "Secure Field"
		case .textEditor: "Text Editor"
		case .toggle: "Toggle"
		case .slider: "Slider"
		case .stepper: "Stepper"
		case .picker: "Picker"
		case .datePicker: "Date Picker"
		case .progress: "Progress"
		case .image: "Symbol"
		case .rectangle: "Rectangle"
		case .circle: "Circle"
		case .capsule: "Capsule"
		case .ellipse: "Ellipse"
		case .divider: "Divider"
		case .vstack: "VStack"
		case .hstack: "HStack"
		case .zstack: "ZStack"
		case .scrollView: "Scroll View"
		case .groupBox: "Group Box"
		case .controlGroup: "Control Group"
		case .menu: "Menu"
		case .form: "Form"
		case .section: "Section"
		case .disclosureGroup: "Disclosure"
		case .photo: "Image"
		case .tabView: "Tab View"
		case .tab: "Tab"
		case .splitView: "Split View"
		case .pane: "Column"
		case .navigationStack: "Nav Stack"
		case .navigationLink: "Nav Link"
		case .spacer: "Spacer"
		}
	}

	var symbol: String {
		switch self {
		case .text: "textformat"
		case .label: "tag"
		case .button: "hand.tap"
		case .link: "link"
		case .textField: "character.cursor.ibeam"
		case .secureField: "key"
		case .textEditor: "text.alignleft"
		case .toggle: "switch.2"
		case .slider: "slider.horizontal.3"
		case .stepper: "plus.forwardslash.minus"
		case .picker: "filemenu.and.selection"
		case .datePicker: "calendar"
		case .progress: "progress.indicator"
		case .image: "star.square"
		case .rectangle: "rectangle.fill"
		case .circle: "circle.fill"
		case .capsule: "capsule.fill"
		case .ellipse: "oval.fill"
		case .divider: "minus"
		case .vstack: "square.split.1x2"
		case .hstack: "square.split.2x1"
		case .zstack: "square.stack"
		case .scrollView: "scroll"
		case .groupBox: "square.dashed.inset.filled"
		case .controlGroup: "rectangle.split.3x1"
		case .menu: "filemenu.and.cursorarrow"
		case .form: "list.bullet.rectangle"
		case .section: "rectangle.grid.1x2"
		case .disclosureGroup: "chevron.down.square"
		case .photo: "photo"
		case .tabView: "rectangle.topthird.inset.filled"
		case .tab: "rectangle.on.rectangle"
		case .splitView: "sidebar.left"
		case .pane: "rectangle.portrait"
		case .navigationStack: "square.stack.3d.up"
		case .navigationLink: "chevron.right.square"
		case .spacer: "arrow.left.and.right"
		}
	}

	var isContainer: Bool {
		[
			.vstack, .hstack, .zstack, .scrollView, .groupBox, .controlGroup, .menu, .form,
			.section, .disclosureGroup, .tabView, .tab, .splitView, .pane, .navigationStack,
			.navigationLink,
		]
		.contains(self)
	}

	/// Containers that only make sense with certain children. Everything else takes anything.
	func accepts(_ child: ComponentKind) -> Bool {
		switch self {
		case .controlGroup: [.button, .toggle, .link, .picker, .menu].contains(child)
		case .menu: [.button, .toggle, .link, .picker, .menu, .divider, .section].contains(child)
		// Tabs only live in tab views, and columns only in split views.
		case .tabView: child == .tab
		case .splitView: child == .pane
		default: isContainer && child != .tab && child != .pane
		}
	}

	/// Containers offered by "Group In", in menu order.
	static let wrappers: [ComponentKind] = [
		.vstack, .hstack, .zstack, .scrollView, .controlGroup, .menu, .form, .section,
		.disclosureGroup, .groupBox,
	]

	/// Groups whose children lay out top to bottom (as opposed to side by side or overlapping).
	var stacksVertically: Bool {
		[.vstack, .groupBox, .form, .section, .disclosureGroup, .menu].contains(self)
	}
	var isStack: Bool { self == .vstack || self == .hstack }
	var isShape: Bool { [.rectangle, .circle, .capsule, .ellipse].contains(self) }
	var usesFont: Bool {
		[
			.text, .label, .button, .link, .textField, .secureField, .textEditor, .toggle,
			.stepper, .picker, .datePicker, .image,
		].contains(self)
	}
	var hasTitle: Bool {
		[
			.text, .label, .button, .link, .toggle, .stepper, .picker, .datePicker, .groupBox,
			.menu, .section, .disclosureGroup, .tab, .pane, .navigationLink,
		].contains(self)
	}
	var hasPlaceholder: Bool { self == .textField || self == .secureField }
	var usesSymbol: Bool { self == .image || self == .label || self == .menu || self == .tab }
	/// Components whose look follows the accent color (`.tint`).
	var usesAccent: Bool {
		[
			.button, .link, .toggle, .slider, .stepper, .picker, .datePicker, .progress, .textField,
			.secureField, .textEditor, .controlGroup, .menu, .tabView, .navigationLink,
			.disclosureGroup,
		].contains(self)
	}

	/// Controls that respond to `.controlSize`.
	var usesControlSize: Bool {
		[
			.button, .link, .textField, .secureField, .toggle, .slider, .stepper, .picker,
			.datePicker, .progress, .controlGroup, .menu,
		].contains(self)
	}

	enum Family { case control, shape, layout, group, navigation }

	/// What kind of thing this is, for coloring its icon.
	var family: Family {
		switch self {
		case .text, .label, .button, .link, .textField, .secureField, .textEditor,
			.toggle, .slider, .stepper, .picker, .datePicker, .progress:
			.control
		case .image, .photo, .rectangle, .circle, .capsule, .ellipse, .divider: .shape
		case .vstack, .hstack, .zstack, .scrollView, .spacer: .layout
		case .controlGroup, .menu, .form, .section, .groupBox, .disclosureGroup: .group
		case .tabView, .tab, .splitView, .pane, .navigationStack, .navigationLink: .navigation
		}
	}

	/// Accent used for this kind's icon in the palette and layers list.
	/// One color per Library group, cycling so neighboring groups differ. The same color is used
	/// for the component in Layers and the Inspector.
	var tint: Color { Self.nativeTints[groupIndex % Self.nativeTints.count] }

	static let nativeTints: [Color] = [.blue, .orange, .purple, .teal, .indigo]

	/// Which Library group this kind is in. Kinds not listed there go with their parent's group
	/// (a Column with Split View, a Tab with Tab View).
	var groupIndex: Int {
		let kind: ComponentKind = self == .pane ? .splitView : self
		return Self.groups.firstIndex { $0.kinds.contains(kind) } ?? 0
	}

	static let groups: [(title: String, kinds: [ComponentKind])] = [
		("Text", [.text, .label, .link]),
		("Controls", [.button, .toggle, .slider, .stepper, .picker, .datePicker, .progress]),
		("Input", [.textField, .secureField, .textEditor]),
		("Shapes & Media", [.photo, .image, .rectangle, .circle, .capsule, .ellipse, .divider]),
		("Layout", [.vstack, .hstack, .zstack, .scrollView, .spacer]),
		("Groups", [.controlGroup, .menu, .form, .section, .disclosureGroup, .groupBox]),
		("Navigation", [.tabView, .tab, .splitView, .navigationStack, .navigationLink]),
	]
}
