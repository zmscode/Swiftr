import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Drops into a design window are handled once for the whole window: every component reports its
// frame, and the drop goes into the innermost container under the pointer that accepts it, at the
// position between its children nearest the pointer.

enum DesignSpace {
	static let name = "designWindow"
}

struct NodeFramesKey: PreferenceKey {
	static let defaultValue: [UUID: CGRect] = [:]
	static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
		value.merge(nextValue()) { $1 }
	}
}

extension View {
	/// Reports this component's frame in the window, for drop targeting.
	func reportFrame(_ id: UUID) -> some View {
		background(
			GeometryReader { geo in
				Color.clear.preference(
					key: NodeFramesKey.self, value: [id: geo.frame(in: .named(DesignSpace.name))])
			}
		)
	}

	/// Makes a view draggable with a Swiftr payload, noting the payload when the drag starts.
	func dragSource(payload: String, model: DesignModel, kind: ComponentKind) -> some View {
		onDrag {
			model.draggingPayload = payload
			return NSItemProvider(object: payload as NSString)
		} preview: {
			DragPreview(kind: kind)
		}
	}
}

extension DesignModel {
	/// The component a drag payload would place: the one being moved, or a new one of the kind.
	func node(forPayload payload: String?) -> Node? {
		guard let payload else { return nil }
		if payload.hasPrefix("new:"),
			let kind = ComponentKind(rawValue: String(payload.dropFirst(4)))
		{
			return Node.make(kind)
		}
		if payload.hasPrefix("move:"), let id = UUID(uuidString: String(payload.dropFirst(5))) {
			return project.find(id)
		}
		return nil
	}

	/// Where a drop at `point` in a window lands: the innermost container under the point that
	/// accepts the dragged component, at the index between children nearest the point.
	func resolveDrop(at point: CGPoint, in windowID: UUID, frames: [UUID: CGRect]) -> DropTarget? {
		guard let window = project.window(windowID) else { return nil }
		let dragged = node(forPayload: draggingPayload)
		let movingID = draggingPayload?.hasPrefix("move:") == true ? dragged?.id : nil

		var candidates: [Node] = []
		func visit(_ node: Node) {
			// A component can't be dropped into itself or anything inside it.
			if node.id == movingID { return }
			guard let frame = frames[node.id], frame.contains(point) else { return }
			if node.kind.isContainer { candidates.append(node) }
			for child in node.children { visit(child) }
		}
		visit(window.root)

		let container = candidates.last { candidate in
			dragged.map { candidate.kind.accepts($0.kind) } ?? true
		}
		guard let container else { return nil }
		return .at(container.id, index: insertionIndex(in: container, at: point, frames: frames))
	}

	private func insertionIndex(in container: Node, at point: CGPoint, frames: [UUID: CGRect])
		-> Int
	{
		// Children drawn without frames (inside control groups and menus): add at the end.
		guard container.children.allSatisfy({ frames[$0.id] != nil }) else {
			return container.children.count
		}
		switch container.layoutAxis {
		case nil: return container.children.count
		case .horizontal?:
			return container.children.filter { (frames[$0.id]?.midX ?? .infinity) < point.x }.count
		case .vertical?:
			return container.children.filter { (frames[$0.id]?.midY ?? .infinity) < point.y }.count
		}
	}
}

extension Node {
	/// The direction children flow in, or nil when they overlap (ZStack).
	var layoutAxis: Axis? {
		switch kind {
		case .hstack, .controlGroup, .splitView: .horizontal
		case .tabView: nil
		case .scrollView: props.scrollAxis == .horizontal ? .horizontal : .vertical
		case .zstack: nil
		default: .vertical
		}
	}
}

struct WindowDropDelegate: DropDelegate {
	let model: DesignModel
	let windowID: UUID
	let frames: [UUID: CGRect]

	func validateDrop(info: DropInfo) -> Bool {
		!model.isPreviewing && info.hasItemsConforming(to: [.plainText, .fileURL])
	}

	func dropUpdated(info: DropInfo) -> DropProposal? {
		let target = model.resolveDrop(at: info.location, in: windowID, frames: frames)
		if model.dropIndicator != target { model.dropIndicator = target }
		guard target != nil else { return DropProposal(operation: .forbidden) }
		let isMove = model.draggingPayload?.hasPrefix("move:") == true
		return DropProposal(operation: isMove ? .move : .copy)
	}

	func dropExited(info: DropInfo) {
		model.dropIndicator = nil
	}

	func performDrop(info: DropInfo) -> Bool {
		let target = model.resolveDrop(at: info.location, in: windowID, frames: frames)
		model.dropIndicator = nil
		guard let target else { return false }
		let model = model

		// Drags that started inside Swiftr (palette, windows, layers) recorded their payload.
		// Check those first: their string payloads also advertise a URL type, so they'd otherwise
		// look like file drops.
		if let payload = model.draggingPayload {
			model.draggingPayload = nil
			return model.handleDrop(payload, target)
		}

		// Image files dragged in from Finder become Image components.
		let files = info.itemProviders(for: [.fileURL])
			.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
		if !files.isEmpty {
			for provider in files {
				_ = provider.loadObject(ofClass: URL.self) { url, _ in
					guard let url, url.isFileURL else { return }
					Task { @MainActor in model.insertImage(from: url, at: target) }
				}
			}
			return true
		}

		guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
		_ = provider.loadTransferable(type: String.self) { result in
			Task { @MainActor in
				if case .success(let payload) = result { model.handleDrop(payload, target) }
			}
		}
		return true
	}

}

/// The line showing where a drop will insert, between the target container's children.
struct DropIndicator: View {
	@Environment(DesignModel.self) private var model
	let frames: [UUID: CGRect]

	var body: some View {
		if case .at(let id, let index)? = model.dropIndicator,
			let container = model.project.find(id),
			let box = frames[id], let line = lineRect(container, box, index)
		{
			Capsule()
				.fill(Color.selectionBlue)
				.frame(width: line.width, height: line.height)
				.position(x: line.midX, y: line.midY)
				.allowsHitTesting(false)
		}
	}

	private func lineRect(_ container: Node, _ box: CGRect, _ index: Int) -> CGRect? {
		let children = container.children.compactMap { frames[$0.id] }
		guard !children.isEmpty, let axis = container.layoutAxis else { return nil }
		let before = index > 0 ? children[min(index, children.count) - 1] : nil
		let after = index < children.count ? children[index] : nil
		switch axis {
		case .vertical:
			let y =
				before.flatMap { b in after.map { (b.maxY + $0.minY) / 2 } }
				?? after.map { $0.minY - 3 } ?? before!.maxY + 3
			return CGRect(x: box.minX + 6, y: y - 1.5, width: max(box.width - 12, 20), height: 3)
		case .horizontal:
			let x =
				before.flatMap { b in after.map { (b.maxX + $0.minX) / 2 } }
				?? after.map { $0.minX - 3 } ?? before!.maxX + 3
			return CGRect(x: x - 1.5, y: box.minY + 6, width: 3, height: max(box.height - 12, 20))
		}
	}
}
