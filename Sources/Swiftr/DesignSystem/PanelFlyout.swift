import SwiftUI

/// A one-line summary of a group of settings (an icon, title and short description, with an
/// optional swatch). Clicking it opens the full settings in a popover beside the panel; − removes
/// the group.
struct PanelFlyoutRow<Content: View>: View {
	let icon: String
	let title: String
	var summary: String = ""
	var swatch: RGBA? = nil
	var help: String? = nil
	var onRemove: (() -> Void)? = nil
	@ViewBuilder let content: Content
	@Environment(\.panelTheme) private var panelTheme
	@State private var isOpen = false
	@State private var isHovered = false

	var body: some View {
		HStack(spacing: 6) {
			Button {
				isOpen.toggle()
			} label: {
				HStack(spacing: 7) {
					Image(systemName: icon)
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(panelTheme.accent)
						.frame(width: 16)
					Text(title).font(PanelStyle.labelFont)
					if let swatch { Swatch(color: swatch).frame(width: 12, height: 12) }
					Text(summary)
						.font(PanelStyle.font)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.tail)
					Spacer(minLength: 0)
					Image(systemName: "chevron.right")
						.font(.system(size: 9, weight: .semibold))
						.foregroundStyle(.tertiary)
				}
				.padding(.horizontal, 8)
				.frame(height: PanelStyle.fieldHeight)
				.background(
					RoundedRectangle(cornerRadius: PanelStyle.radius)
						.fill(isOpen ? panelTheme.accent.opacity(0.15) : PanelStyle.fieldFill)
						.opacity(isHovered || isOpen ? 1 : 0.7)
				)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.onHover { isHovered = $0 }
			.tooltip(help ?? "Edit \(title.lowercased())")
			.popover(isPresented: $isOpen, arrowEdge: .leading) {
				VStack(alignment: .leading, spacing: 14) {
					HStack(spacing: 8) {
						Image(systemName: icon)
							.font(.system(size: 13, weight: .semibold))
							.foregroundStyle(panelTheme.accent)
						Text(title).font(.system(size: 14, weight: .semibold))
						Spacer(minLength: 0)
					}
					content
				}
				.fixedSize(horizontal: false, vertical: true)
				.font(PanelStyle.font)
				.padding(18)
				.frame(width: 340)
			}
			if let onRemove {
				PanelIconButton(symbol: "minus", help: "Remove \(title.lowercased())", action: onRemove)
			}
		}
	}
}

/// A row of symbol buttons, one per optional property that isn't set yet.
struct PanelAddBar: View {
	struct Item: Identifiable {
		let icon: String
		let title: String
		let action: () -> Void
		var id: String { title }
	}

	let items: [Item]

	var body: some View {
		FlowLayout(spacing: 4) {
			ForEach(items) { item in
				PanelAddChip(item: item)
			}
		}
	}
}

private struct PanelAddChip: View {
	let item: PanelAddBar.Item
	@Environment(\.panelTheme) private var panelTheme
	@State private var isHovered = false

	var body: some View {
		Button(action: item.action) {
			HStack(spacing: 4) {
				Image(systemName: item.icon).font(.system(size: 10, weight: .medium))
				Text(item.title).font(.system(size: 10))
			}
			.padding(.horizontal, 7)
			.frame(height: 22)
			.foregroundStyle(isHovered ? AnyShapeStyle(panelTheme.accent) : AnyShapeStyle(.secondary))
			.background(
				Capsule().strokeBorder(
					isHovered ? panelTheme.accent : Color.primary.opacity(0.15), lineWidth: 1)
			)
			.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.onHover { isHovered = $0 }
		.help("Add \(item.title.lowercased())")
	}
}

/// Lays children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
	var spacing: CGFloat = 4

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let rows = arrange(subviews, width: proposal.width ?? .infinity)
		let height = rows.last.map { $0.y + $0.height } ?? 0
		let width = rows.map(\.width).max() ?? 0
		return CGSize(width: proposal.width ?? width, height: height)
	}

	func placeSubviews(
		in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
	) {
		for row in arrange(subviews, width: bounds.width) {
			var x = bounds.minX
			for i in row.indices {
				let size = subviews[i].sizeThatFits(.unspecified)
				subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .init(size))
				x += size.width + spacing
			}
		}
	}

	private struct Row {
		var indices: [Int] = []
		var y: CGFloat = 0
		var width: CGFloat = 0
		var height: CGFloat = 0
	}

	private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
		var rows: [Row] = []
		var row = Row()
		for (i, view) in subviews.enumerated() {
			let size = view.sizeThatFits(.unspecified)
			if !row.indices.isEmpty && row.width + spacing + size.width > width {
				rows.append(row)
				row = Row(y: row.y + row.height + spacing)
			}
			row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
			row.height = max(row.height, size.height)
			row.indices.append(i)
		}
		if !row.indices.isEmpty { rows.append(row) }
		return rows
	}
}

/// One labelled setting in a flyout: an icon and name on the left, the control filling the rest.
struct FlyoutField<Content: View>: View {
	let title: String
	let icon: String
	@ViewBuilder let content: Content

	init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.icon = icon
		self.content = content()
	}

	var body: some View {
		HStack(spacing: 10) {
			Label {
				Text(title)
			} icon: {
				Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16)
			}
			.font(PanelStyle.labelFont)
			.frame(width: 104, alignment: .leading)
			content.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}
