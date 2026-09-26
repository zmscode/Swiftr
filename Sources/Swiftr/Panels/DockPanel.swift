import AppKit
import SwiftUI

/// A floating panel's contents: its tabs stacked top to bottom. Click a tab's header to fold it,
/// drag the header to reorder it or move it to the other panel, and drag the edge between two open
/// tabs to share the height differently.
struct DockPanel: View {
	@Environment(DesignModel.self) private var model
	@Environment(\.panelTheme) private var panelTheme
	let side: DockSide
	@State private var frames: [DockTab: CGRect] = [:]
	@State private var dropIndex: Int?

	private var dock: DockLayout { model.dock }
	private static let headerHeight: CGFloat = 28

	var body: some View {
		VStack(spacing: 0) {
			if side == .left {
				LibraryToolbar()
				Divider()
			}
			GeometryReader { geo in
				stack(height: geo.size.height)
			}
			.coordinateSpace(.named(space))
			.onPreferenceChange(DockFramesKey.self) { frames = $0 }
			.overlay {
				// Only while a tab is dragged, so it doesn't get in the way of the tabs' own drops.
				if dock.draggingTab != nil {
					Color.clear
						.contentShape(Rectangle())
						.onDrop(
							of: [.plainText],
							delegate: DockDropDelegate(
								dock: dock, side: side, frames: frames, dropIndex: $dropIndex))
				}
			}
			.overlay(alignment: .topLeading) { dropMarker }
		}
	}

	private var space: String { "dock.\(side.rawValue)" }

	@ViewBuilder
	private func stack(height: CGFloat) -> some View {
		let entries = dock.entries(side)
		let open = entries.filter { !$0.collapsed }
		let available = max(0, height - CGFloat(entries.count) * Self.headerHeight)
		let total = max(open.reduce(0) { $0 + $1.weight }, 0.0001)

		VStack(spacing: 0) {
			ForEach(entries) { entry in
				VStack(spacing: 0) {
					DockTabHeader(entry: entry, height: Self.headerHeight)
					if !entry.collapsed {
						content(entry.tab)
							.frame(height: max(0, available * entry.weight / total))
							.clipped()
							.overlay(alignment: .bottom) {
								if let next = open.drop(while: { $0.tab != entry.tab }).dropFirst()
									.first
								{
									DockResizeHandle(
										a: entry, b: next, total: total, available: available)
								}
							}
					}
				}
				.background {
					GeometryReader { g in
						Color.clear.preference(
							key: DockFramesKey.self, value: [entry.tab: g.frame(in: .named(space))])
					}
				}
			}
			if entries.isEmpty {
				ContentUnavailableView(
					"No Tabs", systemImage: "rectangle.stack",
					description: Text("Drag a tab's header here from the other panel."))
			}
		}
		.frame(maxHeight: .infinity, alignment: .top)
	}

	@ViewBuilder
	private func content(_ tab: DockTab) -> some View {
		switch tab {
		case .components:
			PaletteView()
				.disabled(model.isPreviewing)
				.opacity(model.isPreviewing ? 0.5 : 1)
		case .layers:
			LayersView()
				.disabled(model.isPreviewing)
				.opacity(model.isPreviewing ? 0.5 : 1)
		case .inspector:
			InspectorView()
		case .theme:
			ScrollView { ThemeSection() }
		}
	}

	/// The line showing where a dragged tab will land.
	@ViewBuilder
	private var dropMarker: some View {
		if dock.draggingTab != nil, let index = dropIndex {
			let entries = dock.entries(side)
			let y: CGFloat =
				index < entries.count
				? frames[entries[index].tab]?.minY ?? 0
				: entries.last.flatMap { frames[$0.tab]?.maxY } ?? 0
			Rectangle()
				.fill(panelTheme.accent)
				.frame(height: 2)
				.offset(y: y - 1)
				.allowsHitTesting(false)
		}
	}
}

/// A tab's header: fold chevron, icon, title and the tab's own buttons. It's also the drag handle.
struct DockTabHeader: View {
	@Environment(DesignModel.self) private var model
	@Environment(\.panelTheme) private var panelTheme
	@AppStorage("palette.asList") private var asList = false
	let entry: DockEntry
	let height: CGFloat
	@State private var isHovered = false

	var body: some View {
		HStack(spacing: 6) {
			Image(systemName: "chevron.right")
				.font(.system(size: 8, weight: .bold))
				.rotationEffect(.degrees(entry.collapsed ? 0 : 90))
				.foregroundStyle(.tertiary)
				.frame(width: 10)
			Image(systemName: entry.tab.icon)
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(panelTheme.accent)
			Text(entry.tab.title).font(.system(size: 11, weight: .semibold))
			Spacer(minLength: 0)
			actions
			Image(systemName: "line.3.horizontal")
				.font(.system(size: 10))
				.foregroundStyle(.tertiary)
				.opacity(isHovered ? 1 : 0)
				.help("Drag to move this tab, within this panel or to the other one")
		}
		.padding(.leading, 8)
		.padding(.trailing, 8)
		.frame(height: height)
		.background(Color.primary.opacity(isHovered ? 0.06 : 0.03))
		.overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
		.contentShape(Rectangle())
		.onHover { isHovered = $0 }
		.onTapGesture {
			withAnimation(.easeOut(duration: 0.15)) { model.dock.toggleCollapsed(entry.tab) }
			model.dock.save()
		}
		.onDrag {
			model.dock.draggingTab = entry.tab
			return NSItemProvider(object: "swiftr.tab:\(entry.tab.rawValue)" as NSString)
		} preview: {
			Label(entry.tab.title, systemImage: entry.tab.icon)
				.font(.system(size: 11, weight: .semibold))
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(.regularMaterial, in: Capsule())
		}
		.help("\(entry.tab.help). Click to fold, drag to move")
	}

	@ViewBuilder
	private var actions: some View {
		switch entry.tab {
		case .components:
			PanelIconButton(
				symbol: asList ? "square.grid.2x2" : "list.bullet",
				help: asList ? "Show as grid" : "Show as list"
			) {
				asList.toggle()
			}
		case .layers:
			PanelIconButton(symbol: "macwindow.badge.plus", help: "New window (⌘N)") {
				model.addWindow()
			}
		case .inspector, .theme:
			EmptyView()
		}
	}
}

/// The edge between two open tabs; drag it to give one more height and the other less.
struct DockResizeHandle: View {
	@Environment(DesignModel.self) private var model
	let a: DockEntry
	let b: DockEntry
	let total: Double
	let available: CGFloat
	@State private var start: (Double, Double)?

	/// The least height a tab can be dragged down to.
	private static let minimumHeight = 80.0

	var body: some View {
		Color.clear
			.frame(height: 8)
			.contentShape(Rectangle())
			.offset(y: 4)
			.onHover { inside in
				if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
			}
			.gesture(
				DragGesture(minimumDistance: 1, coordinateSpace: .global)
					.onChanged { value in
						guard available > 0 else { return }
						let s = start ?? (a.weight, b.weight)
						start = s
						let perPoint = total / Double(available)
						let least = Self.minimumHeight * perPoint
						let delta = min(
							max(value.translation.height * perPoint, least - s.0), s.1 - least)
						guard s.0 + s.1 > 2 * least else { return }
						model.dock.setWeights(a.tab, s.0 + delta, b.tab, s.1 - delta)
					}
					.onEnded { _ in
						start = nil
						model.dock.save()
					}
			)
			.help("Drag to resize")
	}
}

private struct DockDropDelegate: DropDelegate {
	let dock: DockLayout
	let side: DockSide
	let frames: [DockTab: CGRect]
	@Binding var dropIndex: Int?

	/// Before the first tab whose middle is below the pointer; after the last otherwise.
	private func index(_ y: CGFloat) -> Int {
		let entries = dock.entries(side)
		return entries.firstIndex { y < (frames[$0.tab]?.midY ?? .infinity) } ?? entries.count
	}

	func validateDrop(info: DropInfo) -> Bool { dock.draggingTab != nil }

	func dropUpdated(info: DropInfo) -> DropProposal? {
		let i = index(info.location.y)
		if dropIndex != i { dropIndex = i }
		return DropProposal(operation: .move)
	}

	func dropExited(info: DropInfo) { dropIndex = nil }

	func performDrop(info: DropInfo) -> Bool {
		defer {
			dropIndex = nil
			dock.draggingTab = nil
		}
		guard let tab = dock.draggingTab else { return false }
		withAnimation(.easeOut(duration: 0.2)) {
			dock.move(tab, to: side, at: index(info.location.y))
		}
		return true
	}
}

private struct DockFramesKey: PreferenceKey {
	static let defaultValue: [DockTab: CGRect] = [:]
	static func reduce(value: inout [DockTab: CGRect], nextValue: () -> [DockTab: CGRect]) {
		value.merge(nextValue()) { $1 }
	}
}
