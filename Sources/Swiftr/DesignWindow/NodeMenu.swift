import SwiftUI

/// Actions shared by the design windows' and layers list's context menus.
struct NodeMenu: View {
	@Environment(DesignModel.self) private var model
	let id: UUID

	var body: some View {
		let isRoot = model.project.isRoot(id)
		let isContainer = model.project.find(id)?.kind.isContainer == true

		if isRoot, let window = model.project.windows.first(where: { $0.root.id == id }) {
			Button("Duplicate Window") { model.duplicateWindow(window.id) }
			Button(model.hiddenWindows.contains(window.id) ? "Show Window" : "Hide Window") {
				if model.hiddenWindows.contains(window.id) {
					model.showWindow(window.id)
				} else {
					model.hideWindow(window.id)
				}
			}
			Divider()
			Button("Paste") {
				model.selection = id
				model.paste()
			}.disabled(!model.canPaste)
			Divider()
			Button("Delete Window", role: .destructive) { model.deleteWindow(window.id) }
		} else {
			let count = model.selectedIDs.contains(id) ? model.editableSelection.count : 1
			let suffix = count > 1 ? " \(count) Items" : ""
			Group {
				Button("Cut\(suffix)") { target { model.cutSelection() } }
				Button("Copy\(suffix)") { target { model.copySelection() } }
				Button("Paste") { target { model.paste() } }.disabled(!model.canPaste)
				Button("Duplicate\(suffix)") { target { model.duplicateSelection() } }
			}
			Divider()
			Button("Move Up") { target { model.moveSelection(by: -1) } }.disabled(count > 1)
			Button("Move Down") { target { model.moveSelection(by: 1) } }.disabled(count > 1)
			Menu("Group\(suffix) In") {
				ForEach(ComponentKind.wrappers) { kind in
					Button {
						target { model.wrapSelection(in: kind) }
					} label: {
						Label(kind.displayName, systemImage: kind.symbol)
					}
					.disabled(!wrappable(kind))
				}
			}
			if isContainer && count == 1 {
				Button("Unwrap") { target { model.unwrapSelection() } }
			}
			Divider()
			Button("Delete\(suffix)", role: .destructive) { target { model.deleteSelection() } }
		}
	}

	/// Right-clicking inside a multiple selection acts on all of it; elsewhere, on just this item.
	private func target(_ action: () -> Void) {
		if !model.selectedIDs.contains(id) { model.selection = id }
		action()
	}

	private func wrappable(_ kind: ComponentKind) -> Bool {
		guard model.selectedIDs.contains(id) else {
			return model.project.find(id).map { kind.accepts($0.kind) } ?? false
		}
		return model.canWrapSelection(in: kind)
	}
}

struct DragPreview: View {
	let kind: ComponentKind
	var body: some View {
		Label(kind.displayName, systemImage: kind.symbol)
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
	}
}
