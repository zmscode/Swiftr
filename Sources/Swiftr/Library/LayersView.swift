import AppKit
import SwiftUI

/// Every window's layers. Click to select (Shift/⌘-click for several), double-click to rename,
/// drag to move, drop components onto rows, right-click for actions.
struct LayersView: View {
	@Environment(DesignModel.self) private var model

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			SidebarHeader(title: "Layers") {
				PanelIconButton(symbol: "macwindow.badge.plus", help: "New window (⌘N)") {
					model.addWindow()
				}
			}
			ScrollView {
				let insideSelection = descendantsOfSelection
				LazyVStack(spacing: 1) {
					ForEach(model.project.windows) { window in
						ForEach(window.root.flattened(collapsed: model.collapsed)) { item in
							LayerRow(
								item: item, window: window,
								isInsideSelection: insideSelection.contains(item.id))
						}
						Color.clear.frame(height: 6)
					}
				}
				.padding(.horizontal, 6)
				.padding(.bottom, 8)
			}
			.onChange(of: model.selection) { _, selection in
				// Bring the window holding the selection forward, without taking focus from the panel.
				guard let selection, let i = model.project.windowIndex(containing: selection) else {
					return
				}
				let id = model.project.windows[i].id
				if !model.hiddenWindows.contains(id) {
					model.windowManager?.focus(id, makeKey: false)
				}
			}
		}
	}

	/// Components inside a selected container, which get a lighter highlight.
	private var descendantsOfSelection: Set<UUID> {
		var ids = Set<UUID>()
		func collect(_ node: Node) {
			for child in node.children {
				ids.insert(child.id)
				collect(child)
			}
		}
		for id in model.selectedIDs where !model.project.isRoot(id) {
			if let node = model.project.find(id) { collect(node) }
		}
		return ids
	}
}

struct LayerRow: View {
	@Environment(\.panelTheme) private var panelTheme
	@Environment(DesignModel.self) private var model
	let item: LayerItem
	let window: DesignWindow
	let isInsideSelection: Bool
	@State private var isHovered = false
	@State private var isRenaming = false
	@State private var draftName = ""
	@FocusState private var renameFocused: Bool

	private var node: Node { item.node }
	private var isRoot: Bool { node.id == window.root.id }
	private var isSelected: Bool { model.selectedIDs.contains(node.id) }
	private var isHidden: Bool { model.hiddenWindows.contains(window.id) }
	private static let rowHeight: CGFloat = 24

	var body: some View {
		HStack(spacing: 4) {
			disclosure
			Image(systemName: isRoot ? "macwindow" : node.kind.symbol)
				.font(.system(size: 11))
				.foregroundStyle(
					isRoot ? AnyShapeStyle(.secondary) : AnyShapeStyle(panelTheme.tint(node.kind))
				)
				.frame(width: 16)
			if isRoot {
				Text(window.settings.title.isEmpty ? window.viewName : window.settings.title)
					.font(.system(size: 11, weight: .semibold))
					.opacity(isHidden ? 0.5 : 1)
					.lineLimit(1)
					.opacity(isRenaming ? 0 : 1)
			} else {
				Text(node.displayName)
					.font(PanelStyle.font)
					.lineLimit(1)
					.opacity(isRenaming ? 0 : 1)
			}
			Spacer(minLength: 0)
			if isRoot && (isHovered || isHidden) {
				PanelIconButton(
					symbol: isHidden ? "eye.slash" : "eye",
					help: isHidden ? "Show window" : "Hide window"
				) {
					if isHidden { model.showWindow(window.id) } else { model.hideWindow(window.id) }
				}
			}
		}
		.overlay(alignment: .leading) { renameField }
		.padding(.leading, 4 + CGFloat(item.depth) * 14)
		.padding(.trailing, 4)
		.frame(height: Self.rowHeight)
		.background(
			RoundedRectangle(cornerRadius: 5)
				.fill(rowFill)
		)
		.overlay { dropMarker }
		.contentShape(Rectangle())
		.onHover { isHovered = $0 }
		.onTapGesture { click() }
		.if(!isRoot) {
			$0.dragSource(payload: "move:\(node.id.uuidString)", model: model, kind: node.kind)
		}
		.onDrop(of: [.plainText], delegate: LayerDropDelegate(model: model, nodeID: node.id, target: dropTarget))
		.contextMenu { NodeMenu(id: node.id) }
	}

	private var rowFill: Color {
		if isSelected { return panelTheme.accent.opacity(0.22) }
		if isInsideSelection { return panelTheme.accent.opacity(0.07) }
		if isHovered { return Color.primary.opacity(0.06) }
		return .clear
	}

	@ViewBuilder
	private var disclosure: some View {
		if node.kind.isContainer && !node.children.isEmpty {
			let isCollapsed = model.collapsed.contains(node.id)
			Button {
				if isCollapsed {
					model.collapsed.remove(node.id)
				} else {
					model.collapsed.insert(node.id)
				}
			} label: {
				Image(systemName: "chevron.right")
					.font(.system(size: 8, weight: .bold))
					.rotationEffect(.degrees(isCollapsed ? 0 : 90))
					.frame(width: 12, height: 20)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.foregroundStyle(.tertiary)
		} else {
			Color.clear.frame(width: 12)
		}
	}

	/// Inline rename, over the name: the layer name, or the window title for a window.
	@ViewBuilder
	private var renameField: some View {
		if isRenaming {
			TextField("", text: $draftName)
				.textFieldStyle(.plain)
				.font(PanelStyle.font)
				.focused($renameFocused)
				.padding(.horizontal, 3)
				.background(
					RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .textBackgroundColor))
				)
				.overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(panelTheme.accent))
				.padding(.leading, 36)
				.onAppear { renameFocused = true }
				.onSubmit(commitRename)
				.onExitCommand { isRenaming = false }
				.onChange(of: renameFocused) { _, focused in if !focused { commitRename() } }
		}
	}

	private func click() {
		let event = NSApp.currentEvent
		if let flags = event?.modifierFlags, flags.contains(.shift) || flags.contains(.command) {
			model.select(node.id, extending: true)
		} else if event?.clickCount == 2 {
			draftName = isRoot ? window.settings.title : (node.name ?? node.summary)
			isRenaming = true
		} else {
			model.select(node.id)
		}
	}

	private func commitRename() {
		guard isRenaming else { return }
		isRenaming = false
		if isRoot {
			model.windowBinding(window.id, \.title).wrappedValue = draftName
		} else {
			// Renaming to the automatic summary clears the custom name.
			model.renameNode(node.id, to: draftName == node.summary ? "" : draftName)
		}
	}

	/// Containers accept drops into themselves except near their top edge; leaves insert before/after.
	/// Where a drop at `location` on this row goes. Containers: the top quarter inserts before,
	/// the bottom quarter after (when folded or empty), the middle inside. Leaves: above or below.
	private func dropTarget(at location: CGPoint) -> DropTarget {
		if isRoot { return .into(node.id) }
		if node.kind.isContainer {
			let showsChildren = !node.children.isEmpty && !model.collapsed.contains(node.id)
			if location.y < Self.rowHeight * 0.25 { return .beside(node.id, after: false) }
			if location.y > Self.rowHeight * 0.75 && !showsChildren { return .beside(node.id, after: true) }
			return .into(node.id)
		}
		return .beside(node.id, after: location.y > Self.rowHeight / 2)
	}

	/// The insertion line above or below this row, or a highlight when dropping into it.
	@ViewBuilder
	private var dropMarker: some View {
		switch model.layerDropTarget {
		case .into(let id) where id == node.id:
			RoundedRectangle(cornerRadius: 5)
				.fill(panelTheme.accent.opacity(0.15))
				.overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(panelTheme.accent, lineWidth: 1.5))
				.allowsHitTesting(false)
		case .beside(let id, let after) where id == node.id:
			VStack {
				if after { Spacer() }
				HStack(spacing: 0) {
					Circle().strokeBorder(panelTheme.accent, lineWidth: 1.5).frame(width: 6, height: 6)
					Rectangle().fill(panelTheme.accent).frame(height: 2)
				}
				.padding(.leading, 20 + CGFloat(item.depth) * 14)
				.offset(y: after ? 2 : -2)
				if !after { Spacer() }
			}
			.allowsHitTesting(false)
		default:
			EmptyView()
		}
	}
}

/// Drops onto a layer row. While hovering it drives the insertion line here and the live preview
/// of the rearranged layout in the design windows.
struct LayerDropDelegate: DropDelegate {
	let model: DesignModel
	let nodeID: UUID
	let target: (CGPoint) -> DropTarget

	func validateDrop(info: DropInfo) -> Bool {
		!model.isPreviewing && info.hasItemsConforming(to: [.plainText])
	}

	func dropUpdated(info: DropInfo) -> DropProposal? {
		let target = target(info.location)
		model.previewDrop(at: target)
		// Only show the marker where the drop is allowed (the preview is empty otherwise).
		let allowed = model.dropPreview?.target == target
		let marker = allowed ? target : nil
		if model.layerDropTarget != marker { model.layerDropTarget = marker }
		guard allowed else { return DropProposal(operation: .forbidden) }
		return DropProposal(operation: model.draggingPayload?.hasPrefix("move:") == true ? .move : .copy)
	}

	func dropExited(info: DropInfo) {
		// Another row may already have taken over; only clear what belongs to this row.
		if let current = model.layerDropTarget, refersToThisRow(current) {
			model.layerDropTarget = nil
			model.previewDrop(at: nil)
		}
	}

	func performDrop(info: DropInfo) -> Bool {
		let target = target(info.location)
		model.layerDropTarget = nil
		if let payload = model.draggingPayload {
			model.draggingPayload = nil
			return model.handleDrop(payload, target)
		}
		model.endDropPreview()
		guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
		let model = model
		_ = provider.loadTransferable(type: String.self) { result in
			Task { @MainActor in
				if case .success(let payload) = result { model.handleDrop(payload, target) }
			}
		}
		return true
	}

	private func refersToThisRow(_ target: DropTarget) -> Bool {
		switch target {
		case .into(let id), .at(let id, _), .beside(let id, _): id == nodeID
		}
	}
}
