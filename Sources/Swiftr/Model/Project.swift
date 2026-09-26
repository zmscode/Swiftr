import SwiftUI

enum TitleBarStyle: String, Codable, CaseIterable, Identifiable {
	case standard, hidden, plain
	var id: String { rawValue }
	var title: String {
		switch self {
		case .standard: "Standard"
		case .hidden: "Hidden"
		case .plain: "None"
		}
	}
}

/// Window options that map one-to-one onto SwiftUI scene modifiers (macOS 15).
struct WindowSettings: Codable, Equatable {
	var title = "My App"
	var width = 480.0
	var height = 420.0
	var titleBar: TitleBarStyle = .standard
	var resizable = true
	var floating = false
	var opensAtLaunch = true
}

extension WindowSettings {
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		let d = WindowSettings()
		func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
			(try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
		}
		self.init()
		title = v(.title, d.title)
		width = v(.width, d.width)
		height = v(.height, d.height)
		titleBar = v(.titleBar, d.titleBar)
		resizable = v(.resizable, d.resizable)
		floating = v(.floating, d.floating)
		opensAtLaunch = v(.opensAtLaunch, d.opensAtLaunch)
	}
}

/// One real window in the designed app: its scene settings and its view tree.
struct DesignWindow: Identifiable, Codable, Equatable {
	var id = UUID()
	var viewName = "ContentView"
	var settings = WindowSettings()
	var root = Node.defaultRoot()
	/// Top-left corner on screen while designing. Not part of the generated code.
	var position: CGPoint?
	/// Which components show when, from this window's controls.
	var conditions = ConditionGraph()

	/// The `id:` of the generated `Window` scene, e.g. "contentView".
	var sceneID: String { viewName.prefix(1).lowercased() + viewName.dropFirst() }
}

/// Everything that gets saved to a project file and tracked by undo.
struct Project: Codable, Equatable {
	var appName = "MyApp"
	var windows: [DesignWindow] = [DesignWindow()]
	/// Images used by Image components, stored in the project file itself.
	var images: [ImageAsset] = []
	/// The app's colour scheme and shared Liquid Glass look.
	var theme = ProjectTheme()

	func image(_ id: UUID?) -> ImageAsset? { id.flatMap { id in images.first { $0.id == id } } }

	/// An asset-catalog-friendly name based on `proposed`, not used by another image.
	func uniqueImageName(_ proposed: String, excluding id: UUID? = nil) -> String {
		let words = proposed.lowercased().split { !$0.isLetter && !$0.isNumber }
		let base = words.isEmpty ? "image" : words.joined(separator: "-")
		let taken = Set(images.filter { $0.id != id }.map(\.name))
		var name = base
		var n = 2
		while taken.contains(name) {
			name = "\(base)-\(n)"
			n += 1
		}
		return name
	}

	/// How many Image components show this image.
	func usageCount(of imageID: UUID) -> Int {
		var count = 0
		for w in windows {
			var root = w.root
			root.forEach { if $0.props.imageID == imageID { count += 1 } }
		}
		return count
	}

	func window(_ id: UUID) -> DesignWindow? { windows.first { $0.id == id } }
	func windowIndex(_ id: UUID) -> Int? { windows.firstIndex { $0.id == id } }

	/// The window whose tree contains the node `id`.
	func windowIndex(containing id: UUID) -> Int? {
		windows.firstIndex { $0.root.find(id) != nil }
	}

	/// The project without on-screen window positions, for comparing designs.
	var ignoringPositions: Project {
		var copy = self
		for i in copy.windows.indices { copy.windows[i].position = nil }
		return copy
	}

	func isRoot(_ id: UUID) -> Bool { windows.contains { $0.root.id == id } }

	/// A window's root, and a container that's the only thing in it, act as the window's content:
	/// they fill the window and aren't outlined.
	func fillsWindow(_ id: UUID) -> Bool {
		windows.contains { w in
			w.root.id == id
				|| (w.root.children.count == 1 && w.root.children[0].id == id
					&& w.root.children[0].kind.isContainer)
		}
	}

	// Tree operations across all windows.

	func find(_ id: UUID) -> Node? {
		for w in windows { if let n = w.root.find(id) { return n } }
		return nil
	}

	func parent(of id: UUID) -> Node? {
		for w in windows { if let n = w.root.parent(of: id) { return n } }
		return nil
	}

	@discardableResult
	mutating func modify(_ id: UUID, _ change: (inout Node) -> Void) -> Bool {
		guard let i = windowIndex(containing: id) else { return false }
		return windows[i].root.modify(id, change)
	}

	@discardableResult
	mutating func remove(_ id: UUID) -> Node? {
		guard let i = windowIndex(containing: id) else { return nil }
		return windows[i].root.remove(id)
	}

	@discardableResult
	mutating func insert(_ node: Node, beside siblingID: UUID, after: Bool) -> Bool {
		guard let i = windowIndex(containing: siblingID) else { return false }
		return windows[i].root.insert(node, beside: siblingID, after: after)
	}

	/// A view name that is a valid Swift type name and not used by another window.
	func uniqueViewName(_ proposed: String, excluding id: UUID? = nil) -> String {
		let base = Identifier.typeName(proposed, fallback: "WindowView")
		let taken = Set(windows.filter { $0.id != id }.map(\.viewName))
		var name = base
		var n = 2
		while taken.contains(name) {
			name = "\(base)\(n)"
			n += 1
		}
		return name
	}
}

extension Project {
	/// Missing keys fall back to defaults, so files saved before a property existed still open.
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		self.init()
		appName = (try? c.decodeIfPresent(String.self, forKey: .appName)) ?? appName
		windows = try c.decode([DesignWindow].self, forKey: .windows)
		images = (try? c.decodeIfPresent([ImageAsset].self, forKey: .images)) ?? []
		theme = (try? c.decodeIfPresent(ProjectTheme.self, forKey: .theme)) ?? ProjectTheme()
	}
}

/// An image file kept in the project. `data` is the original file's bytes (base64 in the JSON).
struct ImageAsset: Identifiable, Codable, Equatable {
	var id = UUID()
	/// The name used in generated code (`Image("name")`) and in the exported asset catalog.
	var name: String
	var data: Data
	/// The original file extension, used when exporting.
	var fileExtension: String
}

// MARK: - Dropping

enum DropTarget: Equatable {
	case into(UUID)  // append to a container
	case at(UUID, index: Int)  // insert into a container at a position
	case beside(UUID, after: Bool)  // insert next to a sibling
}

extension Project {
	/// The container a drop at `target` would go into.
	func parentID(for target: DropTarget) -> UUID? {
		switch target {
		case .into(let id), .at(let id, _): id
		case .beside(let id, _): parent(of: id)?.id
		}
	}

	/// Whether `node` may go at `target`: not into itself or its own children, not next to itself,
	/// and only where the container accepts it (e.g. a Control Group takes buttons and toggles).
	func canDrop(_ node: Node, movingID: UUID?, at target: DropTarget) -> Bool {
		guard let parentID = parentID(for: target), let parent = find(parentID) else {
			return false
		}
		if movingID != nil {
			if node.find(parentID) != nil { return false }
			if case .beside(let sibling, _) = target, sibling == movingID { return false }
		}
		return parent.kind.accepts(node.kind)
	}

	/// Moves (`movingID` set) or adds `node` at `target`. Returns false, changing nothing, if the
	/// drop isn't allowed.
	@discardableResult
	mutating func drop(_ node: Node, movingID: UUID?, at target: DropTarget) -> Bool {
		guard canDrop(node, movingID: movingID, at: target) else { return false }
		var target = target
		if let movingID {
			// Removing the node first shifts later siblings in the same container up by one.
			if case .at(let parentID, let index) = target, parent(of: movingID)?.id == parentID,
				let old = find(parentID)?.children.firstIndex(where: { $0.id == movingID }),
				old < index
			{
				target = .at(parentID, index: index - 1)
			}
			remove(movingID)
		}
		switch target {
		case .into(let parentID):
			modify(parentID) { $0.children.append(node) }
		case .at(let parentID, let index):
			modify(parentID) { $0.children.insert(node, at: min(max(index, 0), $0.children.count)) }
		case .beside(let siblingID, let after):
			insert(node, beside: siblingID, after: after)
		}
		return true
	}
}

extension DesignWindow {
	/// Missing keys fall back to defaults, so files saved before a property existed still open.
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		self.init()
		id = try c.decode(UUID.self, forKey: .id)
		viewName = (try? c.decodeIfPresent(String.self, forKey: .viewName)) ?? viewName
		settings = (try? c.decodeIfPresent(WindowSettings.self, forKey: .settings)) ?? settings
		root = try c.decode(Node.self, forKey: .root)
		position = try? c.decodeIfPresent(CGPoint.self, forKey: .position)
		conditions =
			(try? c.decodeIfPresent(ConditionGraph.self, forKey: .conditions)) ?? ConditionGraph()
	}
}

/// Layout files from before multi-window support: one tree plus canvas size.
struct LegacyDocument: Decodable {
	struct Window: Decodable {
		var title: String
		var width: Double
		var height: Double
	}
	var root: Node
	var window: Window?
}

enum Identifier {
	/// Turns arbitrary text into an UpperCamelCase Swift type name.
	static func typeName(_ text: String, fallback: String) -> String {
		let words = text.split { !$0.isLetter && !$0.isNumber }
		var name = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
		if let first = name.first, first.isNumber { name = "_" + name }
		return name.isEmpty ? fallback : name
	}
}
