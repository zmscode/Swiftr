import SwiftUI

struct Node: Identifiable, Codable, Equatable {
	var id = UUID()
	var kind: ComponentKind
	var props = Props()
	var children: [Node] = []
	/// A name for the layers list, set by the user (nil shows the summary).
	var name: String? = nil

	static func make(_ kind: ComponentKind) -> Node {
		var p = Props()
		switch kind {
		case .text: p.text = "Hello, world!"
		case .label:
			p.text = "Favorites"
			p.systemImage = "star.fill"
		case .button:
			p.text = "Button"
			p.systemImage = "plus"
		case .link: p.text = "Learn more"
		case .textField: p.placeholder = "Enter text"
		case .secureField: p.placeholder = "Password"
		case .textEditor:
			p.fillWidth = true
			p.height = 100
		case .toggle: p.text = "Toggle"
		case .slider: p.value = 0.5
		case .stepper:
			p.text = "Quantity"
			p.value = 1
		case .picker: p.text = "Choice"
		case .datePicker: p.text = "Date"
		case .progress:
			p.value = 0.4
			p.width = 160
		case .image:
			p.systemImage = "star.fill"
			p.fontSize = 32
		case .rectangle:
			p.width = 120
			p.height = 60
			p.cornerRadius = 8
		case .circle, .ellipse:
			p.width = 60
			p.height = 60
		case .capsule:
			p.width = 120
			p.height = 44
		case .vstack, .hstack:
			p.spacing = 8
			p.padding = 8
		case .zstack: p.padding = 8
		case .scrollView:
			p.fillWidth = true
			p.fillHeight = true
			p.spacing = 8
		case .groupBox: p.text = "Group"
		case .section: p.text = "Section"
		case .disclosureGroup:
			p.text = "Details"
			p.isOn = true
		case .form: p.fillWidth = true
		case .menu:
			p.text = "Options"
			p.systemImage = "ellipsis.circle"
		case .photo:
			p.width = 200
			p.height = 140
			p.cornerRadius = 10
		case .tab:
			p.text = "Tab"
			p.systemImage = "square"
		case .pane:
			p.text = "Column"
			p.fillWidth = true
			p.fillHeight = true
			p.align = .start
		case .navigationStack:
			p.fillWidth = true
			p.fillHeight = true
		case .navigationLink: p.text = "Show Details"
		case .controlGroup, .divider, .spacer, .tabView, .splitView: break
		}
		// Groups start with something in them, so they're recognizable when dropped.
		var children: [Node] = []
		switch kind {
		case .controlGroup:
			children = [Node.titled(.button, "Back"), Node.titled(.button, "Forward")]
		case .menu:
			children = [
				Node.titled(.button, "Rename"), Node.titled(.button, "Duplicate"),
				Node.make(.divider),
				Node.titled(.button, "Delete"),
			]
		case .form, .section:
			children = [Node.titled(.toggle, "Enabled"), Node.make(.textField)]
		case .disclosureGroup:
			children = [Node.titled(.text, "More information goes here.")]
		case .tabView:
			children = [Node.tab("Home", "house"), Node.tab("Settings", "gearshape")]
		case .tab:
			children = [Node.titled(.text, "Tab content")]
		case .splitView:
			var sidebar = Node.pane("Sidebar")
			sidebar.children = ["Inbox", "Drafts", "Sent"].map { title in
				var row = Node.make(.label)
				row.props.text = title
				row.props.systemImage = "tray"
				return row
			}
			var detail = Node.pane("Detail")
			detail.props.align = .center
			detail.children = [Node.titled(.text, "Select an item")]
			children = [sidebar, detail]
		case .navigationStack:
			children = [Node.make(.navigationLink)]
		case .navigationLink:
			children = [Node.titled(.text, "Details")]
		default: break
		}
		return Node(kind: kind, props: p, children: children)
	}

	static func tab(_ title: String, _ symbol: String) -> Node {
		var tab = make(.tab)
		tab.props.text = title
		tab.props.systemImage = symbol
		tab.children = [Node.titled(.text, title)]
		return tab
	}

	static func pane(_ title: String) -> Node {
		var pane = make(.pane)
		pane.props.text = title
		return pane
	}

	static func titled(_ kind: ComponentKind, _ title: String) -> Node {
		var node = make(kind)
		node.props.text = title
		return node
	}

	static func defaultRoot() -> Node {
		var p = Props()
		p.fillWidth = true
		p.fillHeight = true
		p.padding = 20
		p.spacing = 12
		// New windows start empty.
		return Node(kind: .vstack, props: p)
	}

	// Tree helpers

	func find(_ id: UUID) -> Node? {
		if self.id == id { return self }
		for child in children {
			if let found = child.find(id) { return found }
		}
		return nil
	}

	@discardableResult
	mutating func modify(_ id: UUID, _ change: (inout Node) -> Void) -> Bool {
		if self.id == id {
			change(&self)
			return true
		}
		for i in children.indices {
			if children[i].modify(id, change) { return true }
		}
		return false
	}

	@discardableResult
	mutating func remove(_ id: UUID) -> Node? {
		if let i = children.firstIndex(where: { $0.id == id }) {
			return children.remove(at: i)
		}
		for i in children.indices {
			if let removed = children[i].remove(id) { return removed }
		}
		return nil
	}

	@discardableResult
	mutating func insert(_ node: Node, beside siblingID: UUID, after: Bool) -> Bool {
		if let i = children.firstIndex(where: { $0.id == siblingID }) {
			children.insert(node, at: after ? i + 1 : i)
			return true
		}
		for i in children.indices {
			if children[i].insert(node, beside: siblingID, after: after) { return true }
		}
		return false
	}

	func parent(of id: UUID) -> Node? {
		if children.contains(where: { $0.id == id }) { return self }
		for child in children {
			if let found = child.parent(of: id) { return found }
		}
		return nil
	}

	func withNewIDs() -> Node {
		var copy = self
		copy.id = UUID()
		copy.children = children.map { $0.withNewIDs() }
		return copy
	}

	/// Depth-first list of the tree for the layers panel, skipping the children of collapsed containers.
	func flattened(depth: Int = 0, collapsed: Set<UUID> = []) -> [LayerItem] {
		let own = [LayerItem(node: self, depth: depth)]
		if collapsed.contains(id) { return own }
		return own + children.flatMap { $0.flattened(depth: depth + 1, collapsed: collapsed) }
	}

	/// What the layers list and inspector call this component.
	var displayName: String {
		if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
		return summary
	}

	var summary: String {
		switch kind {
		case .text, .label, .button, .link, .toggle, .stepper, .picker, .datePicker, .groupBox,
			.menu, .section, .disclosureGroup, .tab, .pane, .navigationLink:
			props.text.isEmpty ? kind.displayName : "\(kind.displayName) “\(props.text)”"
		case .image: "Symbol \(props.systemImage)"
		default: kind.displayName
		}
	}
}

extension Node {
	/// Visits every node in the tree, allowing changes.
	mutating func forEach(_ body: (inout Node) -> Void) {
		body(&self)
		for i in children.indices { children[i].forEach(body) }
	}
}

struct LayerItem: Identifiable {
	let node: Node
	let depth: Int
	var id: UUID { node.id }
}
