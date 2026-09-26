import SwiftUI

// Which inspector sections and modifiers make sense for each kind of component.
extension ComponentKind {
	var supportsForeground: Bool {
		!isShape && ![.spacer, .divider, .photo, .tab, .splitView].contains(self)
	}

	var supportsBackground: Bool { ![.spacer, .divider, .tab, .splitView].contains(self) }

	/// Liquid Glass suits text, symbols, buttons and the stacks that hold them, not images,
	/// shapes, inputs or structural containers.
	var supportsGlass: Bool {
		[
			.text, .label, .button, .link, .image, .vstack, .hstack, .zstack, .controlGroup,
			.groupBox,
		]
		.contains(self)
	}

	/// Containers laid out as a stack, with alignment and spacing between children.
	var usesStackLayout: Bool {
		[
			.vstack, .hstack, .scrollView, .groupBox, .tab, .pane, .navigationStack,
			.navigationLink, .disclosureGroup,
		]
		.contains(self)
	}

	/// Tabs fill their tab view, and sections are sized by their form or list.
	var hasSize: Bool { ![.tab, .section].contains(self) }
}

/// A named style for a component (`.textFieldStyle(.plain)`, `.progressViewStyle(.circular)`…).
/// `code` is the modifier the generated code uses; nil for the SwiftUI default.
struct StyleVariant: Identifiable, Equatable {
	let id: String
	let title: String
	let code: String?
}

extension ComponentKind {
	/// Styles SwiftUI offers for this kind, default first. Buttons, toggles and pickers have
	/// their own style properties.
	var variants: [StyleVariant] {
		switch self {
		case .textField, .secureField:
			[
				StyleVariant(
					id: "roundedBorder", title: "Rounded", code: ".textFieldStyle(.roundedBorder)"),
				StyleVariant(
					id: "squareBorder", title: "Square", code: ".textFieldStyle(.squareBorder)"),
				StyleVariant(id: "plain", title: "Plain", code: ".textFieldStyle(.plain)"),
			]
		case .datePicker:
			[
				StyleVariant(id: "automatic", title: "Automatic", code: nil),
				StyleVariant(id: "field", title: "Field", code: ".datePickerStyle(.field)"),
				StyleVariant(
					id: "stepperField", title: "Stepper", code: ".datePickerStyle(.stepperField)"),
				StyleVariant(
					id: "graphical", title: "Calendar", code: ".datePickerStyle(.graphical)"),
			]
		case .progress:
			[
				StyleVariant(id: "automatic", title: "Automatic", code: nil),
				StyleVariant(id: "linear", title: "Bar", code: ".progressViewStyle(.linear)"),
				StyleVariant(
					id: "circular", title: "Circle", code: ".progressViewStyle(.circular)"),
			]
		case .label:
			[
				StyleVariant(id: "automatic", title: "Automatic", code: nil),
				StyleVariant(id: "titleAndIcon", title: "Both", code: ".labelStyle(.titleAndIcon)"),
				StyleVariant(id: "iconOnly", title: "Icon", code: ".labelStyle(.iconOnly)"),
				StyleVariant(id: "titleOnly", title: "Title", code: ".labelStyle(.titleOnly)"),
			]
		case .form:
			[
				StyleVariant(id: "grouped", title: "Grouped", code: ".formStyle(.grouped)"),
				StyleVariant(id: "columns", title: "Columns", code: ".formStyle(.columns)"),
			]
		case .menu:
			[
				StyleVariant(id: "automatic", title: "Automatic", code: nil),
				StyleVariant(id: "button", title: "Button", code: ".menuStyle(.button)"),
				StyleVariant(
					id: "borderlessButton", title: "Borderless",
					code: ".menuStyle(.borderlessButton)"),
			]
		case .controlGroup:
			[
				StyleVariant(id: "automatic", title: "Automatic", code: nil),
				StyleVariant(
					id: "navigation", title: "Navigation", code: ".controlGroupStyle(.navigation)"),
			]
		case .tabView:
			[
				StyleVariant(id: "automatic", title: "Automatic", code: nil),
				StyleVariant(
					id: "tabBarOnly", title: "Tab Bar", code: ".tabViewStyle(.tabBarOnly)"),
				StyleVariant(
					id: "sidebarAdaptable", title: "Sidebar",
					code: ".tabViewStyle(.sidebarAdaptable)"),
			]
		default:
			[]
		}
	}

	/// The chosen style, or the default when none (or an unknown one) is set.
	func variant(_ id: String?) -> StyleVariant? {
		variants.first { $0.id == id } ?? variants.first
	}
}

/// Applies a component's style variant in the design windows, matching `StyleVariant.code`.
struct VariantModifier: ViewModifier {
	let kind: ComponentKind
	let variant: String?

	func body(content: Content) -> some View {
		switch (kind, kind.variant(variant)?.id) {
		case (.textField, "roundedBorder"), (.secureField, "roundedBorder"):
			content.textFieldStyle(.roundedBorder)
		case (.textField, "squareBorder"), (.secureField, "squareBorder"):
			content.textFieldStyle(.squareBorder)
		case (.textField, "plain"), (.secureField, "plain"): content.textFieldStyle(.plain)
		case (.datePicker, "field"): content.datePickerStyle(.field)
		case (.datePicker, "stepperField"): content.datePickerStyle(.stepperField)
		case (.datePicker, "graphical"): content.datePickerStyle(.graphical)
		case (.progress, "linear"): content.progressViewStyle(.linear)
		case (.progress, "circular"): content.progressViewStyle(.circular)
		case (.label, "titleAndIcon"): content.labelStyle(.titleAndIcon)
		case (.label, "iconOnly"): content.labelStyle(.iconOnly)
		case (.label, "titleOnly"): content.labelStyle(.titleOnly)
		case (.form, "grouped"): content.formStyle(.grouped)
		case (.form, "columns"): content.formStyle(.columns)
		case (.menu, "button"): content.menuStyle(.button)
		case (.menu, "borderlessButton"): content.menuStyle(.borderlessButton)
		case (.controlGroup, "navigation"): content.controlGroupStyle(.navigation)
		case (.tabView, "tabBarOnly"): content.tabViewStyle(.tabBarOnly)
		case (.tabView, "sidebarAdaptable"): content.tabViewStyle(.sidebarAdaptable)
		default: content
		}
	}
}
