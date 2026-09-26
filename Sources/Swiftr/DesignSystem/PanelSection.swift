import SwiftUI

/// A titled group of properties. The chevron next to the title (shown on hover) collapses it, and
/// that's remembered per title. `onAdd`/`onRemove` show + or − for optional properties; a section
/// with `onAdd` shows only its header until the property is added.
struct PanelSection<Content: View>: View {
	let title: String
	var onAdd: (() -> Void)? = nil
	var onRemove: (() -> Void)? = nil
	/// Tooltip for the title; defaults to the description of that section in `descriptions`.
	var help: String? = nil
	@ViewBuilder let content: Content
	@AppStorage private var collapsed: Bool
	@State private var isHovered = false

	init(
		_ title: String, onAdd: (() -> Void)? = nil, onRemove: (() -> Void)? = nil,
		collapsedByDefault: Bool = false, help: String? = nil, @ViewBuilder content: () -> Content
	) {
		self.title = title
		self.help = help
		self.onAdd = onAdd
		self.onRemove = onRemove
		self.content = content()
		_collapsed = AppStorage(wrappedValue: collapsedByDefault, "panel.collapsed.\(title)")
	}

	private var isEmpty: Bool { onAdd != nil }

	/// What each inspector section does, and the SwiftUI it becomes.
	static var descriptions: [String: String] {
		[
			"Window": "The window's scene settings: title, size, title bar and behavior (a Window scene in the generated app)",
			"Content": "What the component shows: its text, symbol, value or options",
			"Style": "SwiftUI's built-in styles for this component, and its control size",
			"Layout": "How children are arranged: direction, alignment, spacing and padding",
			"Size": "Width and height. Hug fits the content, Fixed sets a size, Fill takes the space available (.frame)",
			"Image": "Which image, its shape, how it fits its frame (.aspectRatio) and which part stays visible when cropped",
			"Adjustments": "Color and focus effects on the image (.grayscale, .saturation, .brightness, .contrast, .blur)",
			"Appearance": "Opacity (.opacity) and corner radius",
			"Typography": "Font size and weight (.font)",
			"Fill": "The shape's color (.fill)",
			"Accent": "The control's highlight color, e.g. a switch's on color or a slider's track (.tint)",
			"Foreground": "The color of text and symbols (.foregroundStyle)",
			"Background": "A color behind the component, rounded by the corner radius (.background)",
			"Border": "An outline around the component, or around an image's shape (.overlay with .strokeBorder)",
			"Shadow": "A drop shadow (.shadow)",
			"Liquid Glass": "macOS 26 glass material (.glassEffect, or the glass button style for buttons)",
			"Condition": "Show this only when a control in this window is set (an if statement in the generated code)",
			"Code": "The SwiftUI for this component, ready to copy",
			"Symbol": "The symbol's colors and how it uses them (.symbolRenderingMode, .foregroundStyle)",
			"App": "The app's name, used for the generated App struct",
			"Windows": "Every window in the project; click one to edit it",
			"Images": "Images stored in the project; their names are used in Image(\"name\")",
		]
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 4) {
				Button {
					withAnimation(.easeOut(duration: 0.15)) { collapsed.toggle() }
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "chevron.right")
							.font(.system(size: 8, weight: .bold))
							.rotationEffect(.degrees(collapsed ? 0 : 90))
							.foregroundStyle(.tertiary)
							.opacity(!isEmpty && (isHovered || collapsed) ? 1 : 0)
						Text(title)
							.font(.system(size: 11, weight: .semibold))
							.tooltip(help ?? Self.descriptions[title])
							.foregroundStyle(isEmpty ? .secondary : .primary)
						Spacer(minLength: 0)
					}
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.disabled(isEmpty)
				if let onAdd {
					PanelIconButton(
						symbol: "plus", help: "Add \(title.lowercased())", action: onAdd)
				}
				if let onRemove {
					PanelIconButton(
						symbol: "minus", help: "Remove \(title.lowercased())", action: onRemove)
				}
			}
			.frame(height: 22)
			if !isEmpty && !collapsed { content }
		}
		.padding(.leading, 8)
		.padding(.trailing, 10)
		.padding(.top, 8)
		.padding(.bottom, isEmpty || collapsed ? 6 : 14)
		.onHover { isHovered = $0 }
		.overlay(alignment: .bottom) {
			Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
		}
	}
}

/// A small caption above a group of fields, e.g. "Dimensions" above W and H.
struct PanelCaptioned<Content: View>: View {
	let caption: String
	var help: String? = nil
	@ViewBuilder let content: Content

	init(_ caption: String, help: String? = nil, @ViewBuilder content: () -> Content) {
		self.caption = caption
		self.help = help
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			Text(caption).font(.system(size: 10)).foregroundStyle(.secondary).tooltip(help)
			content
		}
	}
}

/// A small text button with an icon, for secondary actions ("Add option", "Choose File…").
struct PanelTextButton: View {
	let title: String
	let symbol: String
	var help: String? = nil
	let action: () -> Void
	@State private var isHovered = false

	var body: some View {
		Button(action: action) {
			Label(title, systemImage: symbol)
				.font(PanelStyle.font)
				.padding(.horizontal, 6)
				.frame(height: 22)
				.background(
					RoundedRectangle(cornerRadius: 4).fill(
						Color.primary.opacity(isHovered ? 0.08 : 0))
				)
				.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.foregroundStyle(.secondary)
		.onHover { isHovered = $0 }
		.tooltip(help)
	}
}

struct PanelIconButton: View {
	let symbol: String
	var help: String = ""
	let action: () -> Void
	@State private var isHovered = false

	var body: some View {
		Button(action: action) {
			Image(systemName: symbol)
				.font(.system(size: 11, weight: .medium))
				.frame(width: 22, height: 22)
				.background(
					RoundedRectangle(cornerRadius: 4).fill(
						Color.primary.opacity(isHovered ? 0.08 : 0))
				)
				.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.foregroundStyle(.secondary)
		.onHover { isHovered = $0 }
		.help(help)
	}
}

/// Two equal columns, the standard property grid.
struct PanelGrid<A: View, B: View>: View {
	@ViewBuilder let a: A
	@ViewBuilder let b: B

	var body: some View {
		HStack(spacing: PanelStyle.gutter) {
			a.frame(maxWidth: .infinity)
			b.frame(maxWidth: .infinity)
		}
	}
}

/// A small caption above a control, used sparingly where an icon isn't enough.
struct PanelCaption: View {
	let text: String
	init(_ text: String) { self.text = text }
	var body: some View {
		Text(text).font(.system(size: 10)).foregroundStyle(.secondary)
	}
}
