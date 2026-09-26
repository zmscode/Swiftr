import SwiftUI

/// A titled group of properties. The chevron next to the title (shown on hover) collapses it, and
/// that's remembered per title. `onAdd`/`onRemove` show + or − for optional properties; a section
/// with `onAdd` shows only its header until the property is added.
struct PanelSection<Content: View>: View {
	let title: String
	var onAdd: (() -> Void)? = nil
	var onRemove: (() -> Void)? = nil
	@ViewBuilder let content: Content
	@AppStorage private var collapsed: Bool
	@State private var isHovered = false

	init(
		_ title: String, onAdd: (() -> Void)? = nil, onRemove: (() -> Void)? = nil,
		collapsedByDefault: Bool = false, @ViewBuilder content: () -> Content
	) {
		self.title = title
		self.onAdd = onAdd
		self.onRemove = onRemove
		self.content = content()
		_collapsed = AppStorage(wrappedValue: collapsedByDefault, "panel.collapsed.\(title)")
	}

	private var isEmpty: Bool { onAdd != nil }

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
	@ViewBuilder let content: Content

	init(_ caption: String, @ViewBuilder content: () -> Content) {
		self.caption = caption
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
			content
		}
	}
}

/// A small text button with an icon, for secondary actions ("Add option", "Choose File…").
struct PanelTextButton: View {
	let title: String
	let symbol: String
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
