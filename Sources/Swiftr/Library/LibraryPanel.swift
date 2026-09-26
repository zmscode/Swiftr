import SwiftUI

/// Floating panel on the left: mode switch and actions, the component palette, and the layers of every window.
struct LibraryPanel: View {
	@Environment(DesignModel.self) private var model

	var body: some View {
		@Bindable var model = model

		VStack(spacing: 0) {
			HStack(spacing: 6) {
				PanelSegmented(
					selection: $model.isPreviewing,
					items: [
						(false, PanelSegmentLabel(text: "Edit", help: "Edit the windows (⌘R)")),
						(
							true,
							PanelSegmentLabel(
								text: "Preview", help: "Try the windows like the finished app (⌘R)")
						),
					]
				)
				.frame(width: 130)

				Spacer(minLength: 0)

				PanelIconButton(symbol: "arrow.uturn.backward", help: "Undo (⌘Z)") { model.undo() }
					.disabled(!model.canUndo)
				PanelIconButton(symbol: "arrow.uturn.forward", help: "Redo (⇧⌘Z)") { model.redo() }
					.disabled(!model.canRedo)
				PanelIconButton(
					symbol: "point.3.connected.trianglepath.dotted", help: "Conditions (⌥⌘K)"
				) {
					model.windowManager?.showConditions()
				}
				PanelIconButton(
					symbol: "chevron.left.forwardslash.chevron.right",
					help: "Show generated code (⌘E)"
				) {
					model.windowManager?.showCode()
				}
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 8)

			Divider()

			VSplitView {
				PaletteView()
					.frame(minHeight: 150, idealHeight: 300)
				LayersView()
					.frame(minHeight: 150)
			}
			.disabled(model.isPreviewing)
			.opacity(model.isPreviewing ? 0.5 : 1)
		}
	}
}

/// A panel area's title with optional trailing controls.
struct SidebarHeader<Trailing: View>: View {
	let title: String
	@ViewBuilder var trailing: Trailing

	init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
		self.title = title
		self.trailing = trailing()
	}

	var body: some View {
		HStack(spacing: 2) {
			Text(title).font(.system(size: 11, weight: .semibold))
			Spacer(minLength: 0)
			trailing
		}
		.frame(height: 22)
		.padding(.leading, 12)
		.padding(.trailing, 8)
		.padding(.top, 8)
	}
}

struct SearchField: View {
	@Binding var text: String

	var body: some View {
		HStack(spacing: 5) {
			Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
			TextField("Filter", text: $text).textFieldStyle(.plain)
				.help("Filter components by name")
			if !text.isEmpty {
				Button {
					text = ""
				} label: {
					Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
				}
				.buttonStyle(.plain)
			}
		}
		.font(PanelStyle.font)
		.fieldChrome()
	}
}
