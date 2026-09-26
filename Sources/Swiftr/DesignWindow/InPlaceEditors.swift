import AppKit
import SwiftUI

/// Double-click on text-like components: edit the text right in the window.
struct InlineTextEditor: View {
	@Environment(DesignModel.self) private var model
	let node: Node
	@FocusState private var focused: Bool

	var body: some View {
		TextField("", text: model.propBinding(node.id, \.text))
			.textFieldStyle(.plain)
			.font(.system(size: node.props.fontSize, weight: node.props.weight.fontWeight))
			.multilineTextAlignment(.center)
			.focused($focused)
			.padding(.horizontal, 3)
			.background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 3))
			.overlay(
				RoundedRectangle(cornerRadius: 3).strokeBorder(Color.selectionBlue, lineWidth: 2)
			)
			.fixedSize()
			.onAppear { focused = true }
			.onSubmit { model.inPlaceEdit = nil }
			.onExitCommand { model.inPlaceEdit = nil }
			.onChange(of: focused) { _, isFocused in
				if !isFocused, model.inPlaceEdit == node.id { model.inPlaceEdit = nil }
			}
	}
}

/// Double-click on a shape: handles. Edge and corner squares resize (switching that
/// axis to a fixed size); the round handles inside a rectangle's corners set its corner radius.
struct ShapeHandles: View {
	@Environment(DesignModel.self) private var model
	let node: Node
	@State private var dragStart: CGSize?
	@State private var radiusStart: Double?

	private enum Handle: CaseIterable {
		case top, bottom, leading, trailing, topLeading, topTrailing, bottomLeading, bottomTrailing
		var x: CGFloat {
			switch self {
			case .leading, .topLeading, .bottomLeading: -1
			case .trailing, .topTrailing, .bottomTrailing: 1
			default: 0
			}
		}
		var y: CGFloat {
			switch self {
			case .top, .topLeading, .topTrailing: -1
			case .bottom, .bottomLeading, .bottomTrailing: 1
			default: 0
			}
		}
	}

	var body: some View {
		GeometryReader { geo in
			let p = node.props
			// The shape's own frame sits inside its padding.
			let inner = CGRect(
				x: p.padding, y: p.padding,
				width: max(0, geo.size.width - p.padding * 2),
				height: max(0, geo.size.height - p.padding * 2))
			ZStack(alignment: .topLeading) {
				Rectangle()
					.strokeBorder(Color.selectionBlue, lineWidth: 1)
					.frame(width: inner.width, height: inner.height)
					.offset(x: inner.minX, y: inner.minY)
					.allowsHitTesting(false)

				if node.kind == .rectangle || node.kind == .photo {
					ForEach(
						[Handle.topLeading, .topTrailing, .bottomLeading, .bottomTrailing],
						id: \.self
					) { corner in
						radiusHandle(corner, in: inner)
					}
				}

				ForEach(Handle.allCases, id: \.self) { handle in
					resizeHandle(handle, in: inner)
				}

				Text(label(inner))
					.font(.system(size: 10, weight: .medium).monospacedDigit())
					.foregroundStyle(.white)
					.padding(.horizontal, 5)
					.padding(.vertical, 1.5)
					.background(Color.selectionBlue, in: RoundedRectangle(cornerRadius: 3))
					.fixedSize()
					.frame(width: inner.width)
					.offset(x: inner.minX, y: inner.maxY + 8)
					.allowsHitTesting(false)
			}
		}
	}

	private func label(_ inner: CGRect) -> String {
		let size = "\(Int(inner.width.rounded())) × \(Int(inner.height.rounded()))"
		return node.kind == .rectangle || node.kind == .photo
			? "\(size)  ◜ \(Int(node.props.cornerRadius))" : size
	}

	private func resizeHandle(_ h: Handle, in inner: CGRect) -> some View {
		Rectangle()
			.fill(Color.white)
			.overlay(Rectangle().strokeBorder(Color.selectionBlue, lineWidth: 1.5))
			.frame(width: 8, height: 8)
			.contentShape(Rectangle().inset(by: -4))
			.position(x: inner.midX + h.x * inner.width / 2, y: inner.midY + h.y * inner.height / 2)
			.onHover { inside in
				let cursor: NSCursor =
					h.y == 0 ? .resizeLeftRight : h.x == 0 ? .resizeUpDown : .crosshair
				if inside { cursor.push() } else { NSCursor.pop() }
			}
			.gesture(
				DragGesture(coordinateSpace: .global)
					.onChanged { drag in
						let start = dragStart ?? inner.size
						dragStart = start
						var w = (start.width + h.x * drag.translation.width).rounded()
						var hgt = (start.height + h.y * drag.translation.height).rounded()
						// Images keep their proportions (unless unlocked): the larger change wins.
						let locked =
							node.kind == .photo && node.props.lockAspect && start.height > 0
						if locked {
							let ratio = start.width / start.height
							if h.y == 0
								|| (h.x != 0
									&& abs(w - start.width) >= abs(hgt - start.height) * ratio)
							{
								hgt = (w / ratio).rounded()
							} else {
								w = (hgt * ratio).rounded()
							}
						}
						model.updateProps(node.id, key: \Props.width) { p in
							if h.x != 0 || locked {
								p.width = max(4, w)
								p.fillWidth = false
							}
							if h.y != 0 || locked {
								p.height = max(4, hgt)
								p.fillHeight = false
							}
						}
					}
					.onEnded { _ in dragStart = nil }
			)
	}

	private func radiusHandle(_ corner: Handle, in inner: CGRect) -> some View {
		let maxRadius = min(inner.width, inner.height) / 2
		let r = min(node.props.cornerRadius, maxRadius)
		// Sit on the corner's diagonal, at least a little inside so it can be grabbed at radius 0.
		let inset = max(r * 0.3, 10)
		return Circle()
			.fill(Color.white)
			.overlay(Circle().strokeBorder(Color.selectionBlue, lineWidth: 1.5))
			.frame(width: 8, height: 8)
			.position(
				x: corner.x < 0 ? inner.minX + inset : inner.maxX - inset,
				y: corner.y < 0 ? inner.minY + inset : inner.maxY - inset
			)
			.help("Drag to change the corner radius")
			.gesture(
				DragGesture(coordinateSpace: .global)
					.onChanged { drag in
						let start = radiusStart ?? node.props.cornerRadius
						radiusStart = start
						// Dragging toward the center increases the radius.
						let inward =
							(-corner.x * drag.translation.width - corner.y * drag.translation.height)
							/ 2
						let radius = (start + inward).rounded().clamped(to: 0...Double(maxRadius))
						model.updateProps(node.id, key: \Props.cornerRadius) {
							$0.cornerRadius = radius
						}
					}
					.onEnded { _ in radiusStart = nil }
			)
	}
}
