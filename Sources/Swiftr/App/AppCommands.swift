import AppKit
import SwiftUI

struct AppCommands: Commands {
	let model: DesignModel

	var body: some Commands {
		CommandGroup(replacing: .appSettings) {}

		CommandGroup(replacing: .newItem) {
			Button("New Window") { model.addWindow() }
				.keyboardShortcut("n")
			Button("New Project") { model.newProject() }
				.keyboardShortcut("n", modifiers: [.command, .option])
			Button("Open…") { model.open() }
				.keyboardShortcut("o")
			Menu("Open Recent") {
				ForEach(model.recentProjects, id: \.self) { url in
					Button(url.deletingPathExtension().lastPathComponent) { model.open(url) }
				}
				Divider()
				Button("Clear Menu") { model.clearRecentProjects() }
					.disabled(model.recentProjects.isEmpty)
			}
		}

		CommandGroup(replacing: .saveItem) {
			Button("Close") { closeKeyWindow() }
				.keyboardShortcut("w")
			Button("Save") { model.save() }
				.keyboardShortcut("s")
			Button("Save As…") { model.saveAs() }
				.keyboardShortcut("s", modifiers: [.command, .shift])
			Button("Export as Swift…") { model.exportSwift() }
				.keyboardShortcut("e", modifiers: [.command, .shift])
			Button("Export Images to Asset Catalog…") { model.exportImages() }
				.disabled(model.project.images.isEmpty)
			Divider()
			Button("Show Generated Code") { model.windowManager?.showCode() }
				.keyboardShortcut("e")
		}

		// Edit commands act on the design, unless a text field is being edited.
		CommandGroup(replacing: .undoRedo) {
			Button("Undo") { TextFocus.forward("undo:") { model.undo() } }
				.keyboardShortcut("z")
			Button("Redo") { TextFocus.forward("redo:") { model.redo() } }
				.keyboardShortcut("z", modifiers: [.command, .shift])
		}

		CommandGroup(replacing: .pasteboard) {
			Button("Cut") { TextFocus.forward("cut:") { model.cutSelection() } }
				.keyboardShortcut("x")
			Button("Copy") { TextFocus.forward("copy:") { model.copySelection() } }
				.keyboardShortcut("c")
			Button("Paste") { TextFocus.forward("paste:") { model.paste() } }
				.keyboardShortcut("v")
			Button("Duplicate") { model.duplicateSelection() }
				.keyboardShortcut("d")
			Button("Delete") { TextFocus.forward("delete:") { model.deleteSelection() } }
			Button("Select All") { TextFocus.forward("selectAll:") {} }
				.keyboardShortcut("a")
		}

		CommandMenu("Arrange") {
			Button("Move Up") { model.moveSelection(by: -1) }
				.keyboardShortcut("[")
			Button("Move Down") { model.moveSelection(by: 1) }
				.keyboardShortcut("]")
			Divider()
			Menu("Group In") {
				ForEach(ComponentKind.wrappers) { kind in
					Button(kind.displayName) { model.wrapSelection(in: kind) }
						.disabled(!model.canWrapSelection(in: kind))
				}
			}
			Button("Group in VStack") { model.wrapSelection(in: .vstack) }
				.keyboardShortcut("g")
			Button("Group in HStack") { model.wrapSelection(in: .hstack) }
				.keyboardShortcut("g", modifiers: [.command, .option])
			Button("Unwrap") { model.unwrapSelection() }
				.keyboardShortcut("g", modifiers: [.command, .shift])
			Divider()
			Button("Select Parent") { model.selectParent() }
				.keyboardShortcut(.upArrow, modifiers: [.command])
		}

		CommandGroup(before: .toolbar) {
			Button(model.isPreviewing ? "Stop Preview" : "Preview") {
				model.isPreviewing.toggle()
				if model.isPreviewing { model.select(nil) }
			}
			.keyboardShortcut("r")
			Divider()
		}

		CommandGroup(before: .windowList) {
			Button("Library") { model.windowManager?.showLibrary() }
				.keyboardShortcut("l", modifiers: [.command, .option])
			Button("Inspector") { model.windowManager?.showInspector() }
				.keyboardShortcut("i", modifiers: [.command, .option])
			Button("Conditions") { model.windowManager?.showConditions() }
				.keyboardShortcut("k", modifiers: [.command, .option])
			Button("Reset Panel Layout") { model.windowManager?.resetPanelLayout() }
			Button("Show All Design Windows") {
				model.hiddenWindows = []
				model.windowManager?.showPanels()
			}
			Divider()
		}
	}

	/// Closing a design window hides it (see `DesignWindowController`); plain-style windows have no
	/// close button, so route through the delegate directly instead of `performClose`.
	private func closeKeyWindow() {
		guard let window = NSApp.keyWindow else { return }
		if let delegate = window.delegate, delegate.windowShouldClose?(window) == false { return }
		window.close()
	}
}
