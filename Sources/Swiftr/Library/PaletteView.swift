import AppKit
import SwiftUI

/// The component library: search, groups you can fold away, shown as a grid of tiles or a list.
struct PaletteView: View {
	@State private var search = ""
	@AppStorage("palette.asList") private var asList = false

	private var groups: [(title: String, kinds: [ComponentKind])] {
		let query = search.trimmingCharacters(in: .whitespaces).lowercased()
		guard !query.isEmpty else { return ComponentKind.groups }
		return ComponentKind.groups
			.map { ($0.title, $0.kinds.filter { $0.displayName.lowercased().contains(query) }) }
			.filter { !$0.1.isEmpty }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			SearchField(text: $search)
				.padding(.horizontal, 10)
				.padding(.top, 8)

			ScrollView {
				VStack(alignment: .leading, spacing: 2) {
					ForEach(groups, id: \.title) { group in
						PaletteGroup(
							title: group.title, kinds: group.kinds, asList: asList,
							forceOpen: !search.isEmpty)
					}
					if groups.isEmpty {
						Text("No matches").foregroundStyle(.tertiary).frame(maxWidth: .infinity)
							.padding(.top, 20)
					}
				}
				.padding(.horizontal, 8)
				.padding(.bottom, 10)
			}
		}
	}
}

/// One foldable group of components. Folded state is remembered per group.
struct PaletteGroup: View {
	let title: String
	let kinds: [ComponentKind]
	let asList: Bool
	/// While searching, every group with matches is open.
	let forceOpen: Bool
	@AppStorage private var collapsed: Bool

	init(title: String, kinds: [ComponentKind], asList: Bool, forceOpen: Bool) {
		self.title = title
		self.kinds = kinds
		self.asList = asList
		self.forceOpen = forceOpen
		_collapsed = AppStorage(wrappedValue: false, "palette.collapsed.\(title)")
	}

	var body: some View {
		let open = forceOpen || !collapsed
		VStack(alignment: .leading, spacing: 4) {
			Button {
				withAnimation(.easeOut(duration: 0.15)) { collapsed.toggle() }
			} label: {
				HStack(spacing: 4) {
					Image(systemName: "chevron.right")
						.font(.system(size: 8, weight: .bold))
						.rotationEffect(.degrees(open ? 90 : 0))
						.foregroundStyle(.tertiary)
					Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
					Spacer()
				}
				.frame(height: 22)
				.padding(.horizontal, 4)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)

			if open {
				if asList {
					VStack(spacing: 0) {
						ForEach(kinds) { PaletteRow(kind: $0) }
					}
				} else {
					LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 4)], spacing: 4) {
						ForEach(kinds) { PaletteTile(kind: $0) }
					}
				}
			}
		}
	}
}

/// Shared behavior for palette items: double-click adds; with several components selected, a
/// click on a group wraps them in it; drag into a window.
private struct PaletteItemBehavior: ViewModifier {
	@Environment(DesignModel.self) private var model
	let kind: ComponentKind

	func body(content: Content) -> some View {
		content
			.contentShape(Rectangle())
			.help(
				kind.isContainer
					? "Drag into a window, double-click to add, or click to group the selected components"
					: "Drag into a window, or double-click to add"
			)
			.onTapGesture {
				if NSApp.currentEvent?.clickCount == 2 {
					model.add(kind)
				} else if model.editableSelection.count > 1, kind.isContainer,
					model.canWrapSelection(in: kind)
				{
					model.wrapSelection(in: kind)
				}
			}
			.dragSource(payload: "new:\(kind.rawValue)", model: model, kind: kind)
	}
}

struct PaletteTile: View {
	@Environment(\.panelTheme) private var panelTheme
	let kind: ComponentKind
	@State private var isHovered = false

	var body: some View {
		VStack(spacing: 6) {
			Image(systemName: kind.symbol)
				.font(.system(size: 17))
				.foregroundStyle(panelTheme.tint(kind))
				.frame(height: 20)
			Text(kind.displayName)
				.font(.system(size: 10))
				.lineLimit(1)
				.minimumScaleFactor(0.8)
		}
		.frame(maxWidth: .infinity, minHeight: 58)
		.background(
			RoundedRectangle(cornerRadius: 6, style: .continuous)
				.fill(Color.primary.opacity(isHovered ? 0.08 : 0))
		)
		.onHover { isHovered = $0 }
		.modifier(PaletteItemBehavior(kind: kind))
	}
}

struct PaletteRow: View {
	@Environment(\.panelTheme) private var panelTheme
	let kind: ComponentKind
	@State private var isHovered = false

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: kind.symbol)
				.font(.system(size: 12))
				.foregroundStyle(panelTheme.tint(kind))
				.frame(width: 18)
			Text(kind.displayName).font(PanelStyle.font)
			Spacer()
		}
		.padding(.horizontal, 8)
		.frame(height: 26)
		.background(
			RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(isHovered ? 0.08 : 0))
		)
		.onHover { isHovered = $0 }
		.modifier(PaletteItemBehavior(kind: kind))
	}
}
