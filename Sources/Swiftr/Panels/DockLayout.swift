import SwiftUI

/// The sections of the floating panels. Each is a tab that can be collapsed, reordered, and moved
/// between the left and right panels.
enum DockTab: String, Codable, CaseIterable, Identifiable {
	case components, layers, inspector, theme
	var id: String { rawValue }

	var title: String {
		switch self {
		case .components: "Components"
		case .layers: "Layers"
		case .inspector: "Inspector"
		case .theme: "Theme"
		}
	}

	var icon: String {
		switch self {
		case .components: "square.grid.2x2"
		case .layers: "square.3.layers.3d"
		case .inspector: "slider.horizontal.3"
		case .theme: "paintpalette"
		}
	}

	var help: String {
		switch self {
		case .components: "Components to drag into a window"
		case .layers: "Every window's components, as a tree"
		case .inspector: "Settings for the selected component, or the app when nothing is selected"
		case .theme: "The app's accent colour, scheme palette and shared Liquid Glass look"
		}
	}
}

enum DockSide: String, Codable, CaseIterable {
	case left, right
}

/// One tab's place in a panel: whether it's folded to its header, and its share of the panel's
/// height among the open tabs.
struct DockEntry: Codable, Equatable, Identifiable {
	var tab: DockTab
	var collapsed = false
	var weight = 1.0
	var id: DockTab { tab }
}

/// Which tabs each panel holds, in order. Remembered between launches.
@Observable @MainActor
final class DockLayout {
	private(set) var left: [DockEntry]
	private(set) var right: [DockEntry]
	/// The tab being dragged, so drop targets know it's a tab and not a component.
	var draggingTab: DockTab?

	// Bumped when the defaults change, so everyone starts from them once.
	private static let key = "dockLayout.2"

	static let defaultLeft = [
		DockEntry(tab: .components, weight: 1), DockEntry(tab: .layers, collapsed: true),
		DockEntry(tab: .theme, collapsed: true),
	]
	static let defaultRight = [DockEntry(tab: .inspector)]

	private struct Saved: Codable {
		var left: [DockEntry]
		var right: [DockEntry]
	}

	init() {
		if let data = UserDefaults.standard.data(forKey: Self.key),
			let saved = try? JSONDecoder().decode(Saved.self, from: data)
		{
			left = saved.left
			right = saved.right
			// Tabs added in later versions go to the end of the right panel.
			let placed = Set((left + right).map(\.tab))
			right += DockTab.allCases.filter { !placed.contains($0) }.map { DockEntry(tab: $0) }
		} else {
			left = Self.defaultLeft
			right = Self.defaultRight
		}
	}

	func entries(_ side: DockSide) -> [DockEntry] { side == .left ? left : right }

	func side(of tab: DockTab) -> DockSide? {
		left.contains { $0.tab == tab } ? .left : right.contains { $0.tab == tab } ? .right : nil
	}

	/// Moves `tab` to `index` in `side` (an index into that panel's tabs before the move).
	func move(_ tab: DockTab, to side: DockSide, at index: Int) {
		guard let from = self.side(of: tab) else { return }
		var target = entries(side)
		var index = index
		let entry: DockEntry
		if from == side {
			guard let i = target.firstIndex(where: { $0.tab == tab }) else { return }
			entry = target.remove(at: i)
			if i < index { index -= 1 }
		} else {
			var source = entries(from)
			guard let i = source.firstIndex(where: { $0.tab == tab }) else { return }
			entry = source.remove(at: i)
			set(source, for: from)
		}
		target.insert(entry, at: min(max(0, index), target.count))
		set(target, for: side)
		save()
	}

	func toggleCollapsed(_ tab: DockTab) {
		update(tab) { $0.collapsed.toggle() }
	}

	/// Sets the height shares of two neighbouring open tabs (while dragging the edge between them).
	func setWeights(_ a: DockTab, _ wa: Double, _ b: DockTab, _ wb: Double) {
		update(a) { $0.weight = wa }
		update(b) { $0.weight = wb }
	}

	func reset() {
		left = Self.defaultLeft
		right = Self.defaultRight
		save()
	}

	func save() {
		if let data = try? JSONEncoder().encode(Saved(left: left, right: right)) {
			UserDefaults.standard.set(data, forKey: Self.key)
		}
	}

	private func update(_ tab: DockTab, _ change: (inout DockEntry) -> Void) {
		guard let side = side(of: tab) else { return }
		var list = entries(side)
		guard let i = list.firstIndex(where: { $0.tab == tab }) else { return }
		change(&list[i])
		set(list, for: side)
	}

	private func set(_ list: [DockEntry], for side: DockSide) {
		if side == .left { left = list } else { right = list }
	}
}
