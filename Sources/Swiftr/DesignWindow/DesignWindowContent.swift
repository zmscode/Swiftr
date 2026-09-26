import SwiftUI

/// The SwiftUI content of a real design window: the window's view tree, plus editing behavior
/// when not previewing.
struct DesignWindowContent: View {
	@Environment(DesignModel.self) private var model
	let windowID: UUID
	@State private var frames: [UUID: CGRect] = [:]

	var body: some View {
		if let window = model.project.window(windowID) {
			NodeView(node: window.root, windowID: windowID, parentAxis: nil)
				.background {
					// Space around the root (e.g. under a hidden title bar) selects the root.
					if !model.isPreviewing {
						Color.clear
							.contentShape(Rectangle())
							.onTapGesture { model.select(window.root.id) }
					}
				}
				.overlay { if !model.isPreviewing { DropIndicator(frames: frames) } }
				.overlay { MarqueeView(windowID: windowID) }
				.coordinateSpace(.named(DesignSpace.name))
				.onPreferenceChange(NodeFramesKey.self) { new in
					frames = new
					model.nodeFrames[windowID] = new
				}
				.onDrop(
					of: [.plainText],
					delegate: WindowDropDelegate(model: model, windowID: windowID, frames: frames))
		}
	}
}

/// The drag-selection box.
struct MarqueeView: View {
	@Environment(DesignModel.self) private var model
	let windowID: UUID

	var body: some View {
		if let marquee = model.marquee, marquee.windowID == windowID {
			Rectangle()
				.fill(Color.selectionBlue.opacity(0.1))
				.overlay(Rectangle().strokeBorder(Color.selectionBlue, lineWidth: 1))
				.frame(width: marquee.rect.width, height: marquee.rect.height)
				.position(x: marquee.rect.midX, y: marquee.rect.midY)
				.allowsHitTesting(false)
		}
	}
}
