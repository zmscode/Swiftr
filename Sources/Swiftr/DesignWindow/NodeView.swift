import AppKit
import SwiftUI

/// Renders one node of the design tree, recursively. In Edit mode, editing behavior is layered on
/// top; in Preview mode it's the plain view with working controls.
struct NodeView: View {
	@Environment(DesignModel.self) private var model
	let node: Node
	let windowID: UUID
	let parentAxis: Axis?

	private var isRoot: Bool { model.project.isRoot(node.id) }
	/// The root, or a lone container in the window: fills it and isn't outlined.
	private var isWindowContent: Bool { model.displayedProject.fillsWindow(node.id) }
	/// The component a drop preview is placing, drawn faded.
	private var isGhost: Bool { model.dropPreview?.ghostID == node.id }
	private var isSelected: Bool { model.selectedIDs.contains(node.id) }
	/// This container is where the current drag would land.
	private var isDropTarget: Bool {
		switch model.dropIndicator {
		case .into(let id), .at(let id, _): id == node.id
		default: false
		}
	}
	private var isEditingInPlace: Bool { model.inPlaceEdit == node.id && !model.isPreviewing }
	private var dragPayload: String { "move:\(node.id.uuidString)" }

	var body: some View {
		let styled = NodeContent(
			node: node, windowID: windowID, live: model.isPreviewing,
			child: { AnyView(NodeView(node: $0, windowID: windowID, parentAxis: nil)) }
		) { axis in
			children(axis: axis)
		}
		.modifier(VariantModifier(kind: node.kind, variant: node.props.variant))
		.modifier(
			StyleModifier(
				props: node.props.themed(model.project.theme), kind: node.kind,
				fillsWindow: isWindowContent))

		if model.isPreviewing {
			// Conditions apply in Preview: a component whose condition is false isn't there at all.
			if model.isShown(node.id) { styled }
		} else if isGhost {
			styled
				.opacity(0.45)
				.overlay(
					RoundedRectangle(cornerRadius: 3)
						.strokeBorder(
							Color.selectionBlue, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
				)
				.allowsHitTesting(false)
		} else if node.kind.isContainer {
			// Containers handle taps on their own empty space; children handle their own. Drops are
			// handled once per window (see `WindowDropDelegate`), using the frames reported here.
			styled
				.reportFrame(node.id)
				.contentShape(Rectangle())
				.onTapGesture { click() }
				// The window's content (root, or the lone container filling it) isn't moved by dragging;
				// dragging its empty space draws a selection box instead.
				.if(!isWindowContent) {
					$0.dragSource(payload: dragPayload, model: model, kind: node.kind)
				}
				.if(isWindowContent) { $0.gesture(marqueeGesture) }
				.contextMenu { NodeMenu(id: node.id) }
				.onHover { hover($0) }
				.overlay(outline)
				.overlay(alignment: .topLeading) { nameTag }
				.overlay(alignment: .topTrailing) { conditionBadge }
		} else {
			// Real controls are inert; a transparent layer on top takes clicks and drags instead.
			styled
				.allowsHitTesting(false)
				.reportFrame(node.id)
				.overlay(leafInteractionLayer)
				.overlay(outline)
				.overlay(alignment: .topLeading) { nameTag }
				.overlay(alignment: .topTrailing) { conditionBadge }
				.overlay { inPlaceEditor }
				.popover(isPresented: symbolBrowserShown, arrowEdge: .trailing) {
					SymbolBrowser(selection: model.propBinding(node.id, \.systemImage)) {
						if node.kind == .image { model.symbolBrowserOpen = false } else { model.inPlaceEdit = nil }
					}
				}
		}
	}

	@ViewBuilder
	private func children(axis: Axis?) -> some View {
		if node.children.isEmpty && !model.isPreviewing {
			VStack(spacing: 4) {
				Image(systemName: "plus.square.dashed").font(.title3)
				Text("Drop components here").font(.caption)
			}
			.foregroundStyle(.tertiary)
			.frame(minWidth: 140, minHeight: 56)
		} else {
			ForEach(node.children) { child in
				NodeView(node: child, windowID: windowID, parentAxis: axis)
			}
		}
	}

	// MARK: Editing layers

	private var leafInteractionLayer: some View {
		Rectangle()
			.fill(Color.clear)
			.contentShape(Rectangle())
			.onTapGesture { click() }
			.dragSource(payload: dragPayload, model: model, kind: node.kind)
			.contextMenu { NodeMenu(id: node.id) }
			.onHover { hover($0) }
	}

	private var marqueeGesture: some Gesture {
		DragGesture(minimumDistance: 3, coordinateSpace: .named(DesignSpace.name))
			.onChanged { drag in
				model.updateMarquee(
					in: windowID, from: drag.startLocation, to: drag.location,
					extending: NSEvent.modifierFlags.contains(.shift))
			}
			.onEnded { _ in model.endMarquee() }
	}

	/// Shift- or Command-click adds to the selection; a double-click edits in place. Checking the
	/// event keeps single clicks instant (no double-click delay).
	private func click() {
		let event = NSApp.currentEvent
		if let flags = event?.modifierFlags, flags.contains(.shift) || flags.contains(.command) {
			model.select(node.id, extending: true)
		} else if event?.clickCount == 2, node.kind == .photo,
			model.nsImage(node.props.imageID) == nil
		{
			// An empty image asks for a file first; once it has one, double-click shows handles.
			model.select(node.id)
			model.chooseImage(for: node.id)
		} else if node.kind == .image, isEditingInPlace, event?.clickCount != 2 {
			// A symbol already being edited: the next click opens the symbol browser.
			model.symbolBrowserOpen = true
		} else if event?.clickCount == 2, !node.kind.isContainer {
			model.beginInPlaceEdit(node.id)
		} else {
			model.select(node.id)
		}
	}

	/// Double-clicking a symbol, label, menu or icon-only button edits its symbol.
	private var editsSymbol: Bool {
		node.kind.usesSymbol || (node.kind == .button && node.props.buttonDisplay == .icon)
	}

	private var symbolBrowserShown: Binding<Bool> {
		Binding(
			// A lone symbol waits for another click; labels and icon buttons open it straight away.
			get: { isEditingInPlace && editsSymbol && (node.kind != .image || model.symbolBrowserOpen) },
			set: { open in
				guard !open else { return }
				// Closing the browser leaves a symbol's size handles up; others stop editing.
				if node.kind == .image { model.symbolBrowserOpen = false } else { model.inPlaceEdit = nil }
			}
		)
	}

	@ViewBuilder
	private var inPlaceEditor: some View {
		if isEditingInPlace {
			if node.kind.isShape || node.kind == .photo {
				ShapeHandles(node: node)
			} else if node.kind == .image {
				// A symbol's size is its font size; another click opens the symbol browser.
				ShapeHandles(node: node, mode: .fontScale)
					.overlay(alignment: .top) {
						if !model.symbolBrowserOpen {
							Text("Click to change symbol")
								.font(.system(size: 10, weight: .medium))
								.foregroundStyle(.white)
								.padding(.horizontal, 5)
								.padding(.vertical, 1.5)
								.background(Color.selectionBlue, in: RoundedRectangle(cornerRadius: 3))
								.fixedSize()
								.offset(y: -20)
								.allowsHitTesting(false)
						}
					}
			} else if node.kind == .divider {
				// A divider runs across its stack: horizontal in a vertical stack, and vice versa.
				ShapeHandles(
					node: node, mode: .length(parentAxis == .horizontal ? .vertical : .horizontal))
			} else if [.text, .button, .link, .toggle].contains(node.kind) && !editsSymbol {
				InlineTextEditor(node: node)
			}
		}
	}

	private func hover(_ inside: Bool) {
		if inside {
			model.hovered = node.id
		} else if model.hovered == node.id {
			model.hovered = nil
		}
	}

	@ViewBuilder
	private var outline: some View {
		Group {
			if isDropTarget {
				RoundedRectangle(cornerRadius: 3)
					.strokeBorder(Color.selectionBlue, lineWidth: 2)
					.background(Color.selectionBlue.opacity(0.08))
			} else if isEditingInPlace {
				EmptyView()
			} else if isSelected && !isRoot {
				RoundedRectangle(cornerRadius: 3)
					.strokeBorder(Color.selectionBlue, lineWidth: 2)
			} else if model.hovered == node.id && !isRoot {
				RoundedRectangle(cornerRadius: 3)
					.strokeBorder(Color.selectionBlue.opacity(0.5), lineWidth: 1)
			} else if node.kind.isContainer && !isWindowContent {
				RoundedRectangle(cornerRadius: 3)
					.strokeBorder(
						Color.secondary.opacity(0.3),
						style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
			}
		}
		.allowsHitTesting(false)
	}

	/// Marks a component that only shows under a condition (it's always shown while editing).
	@ViewBuilder
	private var conditionBadge: some View {
		if let condition = model.condition(for: node.id) {
			Text("if")
				.font(.system(size: 9, weight: .bold, design: .monospaced))
				.foregroundStyle(.white)
				.padding(.horizontal, 4)
				.padding(.vertical, 1)
				.background(Capsule().fill(Color.orange))
				.fixedSize()
				.offset(x: 4, y: -6)
				.help("Shows when \(model.describe(condition))")
		}
	}

	/// A small label above the selected component naming it.
	@ViewBuilder
	private var nameTag: some View {
		if model.selection == node.id && !isRoot && !isEditingInPlace {
			// A zero-height strip along the top edge; the tag hangs above it.
			Color.clear
				.frame(height: 0)
				.overlay(alignment: .bottomLeading) {
					Text(node.kind.displayName)
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(.white)
						.padding(.horizontal, 5)
						.padding(.vertical, 1.5)
						.background(Color.selectionBlue, in: RoundedRectangle(cornerRadius: 3))
						.fixedSize()
						.offset(y: -3)
				}
				.allowsHitTesting(false)
		}
	}
}
