import SwiftUI

/// The left panel's toolbar: undo and redo, the Conditions and code windows, and Edit/Preview.
struct LibraryToolbar: View {
	@Environment(DesignModel.self) private var model

	var body: some View {
		HStack(spacing: 2) {
			PanelIconButton(symbol: "arrow.uturn.backward", help: "Undo (⌘Z)", size: 14) {
				model.undo()
			}
			.disabled(!model.canUndo || model.isPreviewing)
			PanelIconButton(symbol: "arrow.uturn.forward", help: "Redo (⇧⌘Z)", size: 14) {
				model.redo()
			}
			.disabled(!model.canRedo || model.isPreviewing)

			Spacer(minLength: 0)

			PanelIconButton(
				symbol: "point.3.connected.trianglepath.dotted", help: "Conditions (⌥⌘K)",
				size: 14
			) {
				model.windowManager?.showConditions()
			}
			PanelIconButton(
				symbol: "chevron.left.forwardslash.chevron.right",
				help: "Show generated code (⌘E)", size: 14
			) {
				model.windowManager?.showCode()
			}

			Divider().frame(height: 18).padding(.horizontal, 4)

			PanelIconButton(
				symbol: model.isPreviewing ? "pencil" : "play.fill",
				help: model.isPreviewing
					? "Back to editing (⌘R)"
					: "Preview: try the windows like the finished app (⌘R)",
				isActive: model.isPreviewing, size: 14
			) {
				model.isPreviewing.toggle()
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
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
