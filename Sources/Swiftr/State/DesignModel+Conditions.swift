import SwiftUI

extension Project {
	/// Drops condition nodes that refer to components no longer in their window.
	mutating func pruneConditions() {
		for i in windows.indices where !windows[i].conditions.isEmpty {
			var present = Set<UUID>()
			var root = windows[i].root
			root.forEach { present.insert($0.id) }
			let referenced = Set(windows[i].conditions.nodes.compactMap { node -> UUID? in
				switch node.kind {
				case .control(let id), .visible(let id): id
				default: nil
				}
			})
			windows[i].conditions.removeReferences(to: referenced.subtracting(present))
		}
	}
}

/// The simple condition the inspector edits: one control, optionally compared with a value.
struct SimpleCondition: Equatable {
	var source: UUID
	var op: CompareOp?
	var value: ConditionValue?
}

extension DesignModel {
	// MARK: Live values (Preview)

	/// A control's current value: what it's set to in Preview, otherwise its initial value.
	func value(of controlID: UUID) -> ConditionValue? {
		if let live = liveValues[controlID] { return live }
		guard let node = project.find(controlID) else { return nil }
		let p = node.props
		switch node.kind {
		case .toggle: return .bool(p.isOn)
		case .slider: return .number(p.value)
		case .stepper: return .number(Double(Int(p.value)))
		case .picker: return .number(Double(p.selectedIndex))
		case .textField, .secureField, .textEditor: return .text("")
		default: return nil
		}
	}

	func liveBinding(_ controlID: UUID, initial: ConditionValue) -> Binding<ConditionValue> {
		Binding(
			get: { self.liveValues[controlID] ?? initial },
			set: { self.liveValues[controlID] = $0 }
		)
	}

	// MARK: Evaluation

	func evaluate(_ expr: ConditionExpr) -> ConditionValue {
		switch expr {
		case .control(let id): return value(of: id) ?? .bool(false)
		case .constant(let v): return v
		case .not(let e): return .bool(!evaluate(e).bool)
		case .and(let a, let b): return .bool(evaluate(a).bool && evaluate(b).bool)
		case .or(let a, let b): return .bool(evaluate(a).bool || evaluate(b).bool)
		case .compare(let op, let a, let b):
			let l = evaluate(a)
			let r = b.map(evaluate)
			switch op {
			case .isEmpty: return .bool(l.text.isEmpty)
			case .isNotEmpty: return .bool(!l.text.isEmpty)
			case .contains: return .bool(l.text.localizedCaseInsensitiveContains(r?.text ?? ""))
			case .equal, .notEqual:
				let same: Bool
				if case .text = l { same = l.text == (r?.text ?? "") } else { same = l.number == (r?.number ?? 0) }
				return .bool(op == .equal ? same : !same)
			case .less: return .bool(l.number < (r?.number ?? 0))
			case .lessOrEqual: return .bool(l.number <= (r?.number ?? 0))
			case .greater: return .bool(l.number > (r?.number ?? 0))
			case .greaterOrEqual: return .bool(l.number >= (r?.number ?? 0))
			}
		}
	}

	/// The condition on a component, if it has a complete one.
	func condition(for componentID: UUID) -> ConditionExpr? {
		guard let i = project.windowIndex(containing: componentID) else { return nil }
		return project.windows[i].conditions.condition(for: componentID)
	}

	/// In Preview, whether a component's condition currently lets it show.
	func isShown(_ componentID: UUID) -> Bool {
		guard let condition = condition(for: componentID) else { return true }
		return evaluate(condition).bool
	}

	// MARK: Editing (inspector)

	/// All the controls in a window whose values conditions can use.
	func conditionSources(inWindow windowID: UUID) -> [Node] {
		guard var root = project.window(windowID)?.root else { return [] }
		var sources: [Node] = []
		root.forEach { if $0.kind.isConditionSource { sources.append($0) } }
		return sources
	}

	/// Controls in the same window whose values a condition on `componentID` can use.
	func conditionSources(for componentID: UUID) -> [Node] {
		guard let i = project.windowIndex(containing: componentID) else { return [] }
		var sources: [Node] = []
		var root = project.windows[i].root
		root.forEach { if $0.kind.isConditionSource && $0.id != componentID { sources.append($0) } }
		return sources
	}

	/// The component's condition in the inspector's simple form, if it has that shape.
	func simpleCondition(for componentID: UUID) -> SimpleCondition? {
		switch condition(for: componentID) {
		case .control(let id)?:
			return SimpleCondition(source: id)
		case .compare(let op, .control(let id), let rhs)?:
			if let rhs {
				guard case .constant(let v) = rhs else { return nil }
				return SimpleCondition(source: id, op: op, value: v)
			}
			return SimpleCondition(source: id, op: op)
		default:
			return nil
		}
	}

	/// A sensible first condition on a control: a toggle is on, a slider is over halfway, a stepper
	/// is above zero, a picker is on its first option, a text field isn't empty.
	func defaultCondition(source: Node) -> SimpleCondition {
		switch source.kind.conditionValueType {
		case .bool?: SimpleCondition(source: source.id)
		case .text?: SimpleCondition(source: source.id, op: .isNotEmpty)
		default:
			source.kind == .picker
				? SimpleCondition(source: source.id, op: .equal, value: .number(0))
				: SimpleCondition(source: source.id, op: .greater, value: .number(source.kind == .slider ? 0.5 : 0))
		}
	}

	/// Replaces a component's condition with a simple one, laid out left to right for the node editor.
	func setCondition(_ condition: SimpleCondition, for componentID: UUID) {
		guard let w = project.windowIndex(containing: componentID) else { return }
		snapshot(coalescing: EditKey(id: componentID, path: \DesignWindow.conditions))
		var graph = project.windows[w].conditions
		graph.removeCondition(for: componentID)
		// Stack each condition in its own row in the editor.
		let row = CGFloat(graph.nodes.filter { if case .visible = $0.kind { true } else { false } }.count) * 140
		let source = ConditionNode(kind: .control(condition.source), position: CGPoint(x: 0, y: row))
		let visible = ConditionNode(kind: .visible(componentID), position: CGPoint(x: 520, y: row))
		graph.nodes += [source, visible]
		if let op = condition.op {
			let compare = ConditionNode(kind: .compare(op), position: CGPoint(x: 260, y: row))
			graph.nodes.append(compare)
			graph.links.append(ConditionLink(from: source.id, to: compare.id, port: "a"))
			if op.isBinary {
				let constant = ConditionNode(
					kind: .constant(condition.value ?? .number(0)), position: CGPoint(x: 0, y: row + 70))
				graph.nodes.append(constant)
				graph.links.append(ConditionLink(from: constant.id, to: compare.id, port: "b"))
			}
			graph.links.append(ConditionLink(from: compare.id, to: visible.id, port: "in"))
		} else {
			graph.links.append(ConditionLink(from: source.id, to: visible.id, port: "in"))
		}
		project.windows[w].conditions = graph
	}

	func removeCondition(for componentID: UUID) {
		guard let w = project.windowIndex(containing: componentID),
			project.windows[w].conditions.visibilityNode(for: componentID) != nil
		else { return }
		snapshot()
		project.windows[w].conditions.removeCondition(for: componentID)
	}

	/// The condition in words, e.g. "Dark mode is on and Volume > 0.5".
	func describe(_ expr: ConditionExpr) -> String {
		switch expr {
		case .control(let id):
			let name = controlName(id)
			return project.find(id)?.kind == .toggle ? "\(name) is on" : name
		case .constant(let v): return v.text
		case .not(let e): return "not (\(describe(e)))"
		case .and(let a, let b): return "\(describe(a)) and \(describe(b))"
		case .or(let a, let b): return "\(describe(a)) or \(describe(b))"
		case .compare(let op, let a, let b):
			var left = describe(a)
			if case .control(let id) = a { left = controlName(id) }
			var right = b.map(describe) ?? ""
			// Picker options read better by name than by index.
			if case .control(let id) = a, let picker = project.find(id), picker.kind == .picker,
				case .constant(let v)? = b, picker.props.options.indices.contains(Int(v.number))
			{
				right = "“\(picker.props.options[Int(v.number)])”"
			}
			return op.isBinary ? "\(left) \(op.symbol) \(right)" : "\(left) \(op.symbol)"
		}
	}

	func controlName(_ id: UUID) -> String {
		guard let node = project.find(id) else { return "Missing control" }
		if let name = node.name, !name.isEmpty { return name }
		if !node.props.text.isEmpty { return node.props.text }
		if !node.props.placeholder.isEmpty { return node.props.placeholder }
		return node.kind.displayName
	}
}

// MARK: - Node editor

extension DesignModel {
	/// The window the Conditions panel is editing: the one picked there, else the selection's.
	var conditionsWindow: DesignWindow? {
		if let id = conditionsWindowID, let window = project.window(id) { return window }
		return selectedWindow ?? activeWindowID.flatMap { project.window($0) } ?? project.windows.first
	}

	private func editGraph(_ windowID: UUID, coalescing key: AnyHashable? = nil, _ change: (inout ConditionGraph) -> Void) {
		guard let w = project.windowIndex(windowID) else { return }
		var graph = project.windows[w].conditions
		change(&graph)
		guard graph != project.windows[w].conditions else { return }
		snapshot(coalescing: key)
		project.windows[w].conditions = graph
	}

	@discardableResult
	func addConditionNode(_ kind: ConditionNodeKind, in windowID: UUID, at position: CGPoint) -> UUID {
		let node = ConditionNode(kind: kind, position: position)
		editGraph(windowID) { $0.nodes.append(node) }
		return node.id
	}

	func moveConditionNodes(in windowID: UUID, to positions: [UUID: CGPoint]) {
		editGraph(windowID) { graph in
			for i in graph.nodes.indices {
				if let p = positions[graph.nodes[i].id] { graph.nodes[i].position = p }
			}
		}
	}

	/// Removes nodes (and their wires) and wires.
	func deleteConditionItems(in windowID: UUID, nodes: Set<UUID>, links: Set<UUID>) {
		editGraph(windowID) { graph in
			graph.nodes.removeAll { nodes.contains($0.id) }
			graph.links.removeAll { links.contains($0.id) || nodes.contains($0.from) || nodes.contains($0.to) }
		}
	}

	/// Changes what a node is (a constant's value, a comparison's operator, which control it reads).
	func updateConditionNode(in windowID: UUID, _ id: UUID, to kind: ConditionNodeKind) {
		editGraph(windowID, coalescing: EditKey(id: id, path: \ConditionNode.kind)) { graph in
			guard let i = graph.nodes.firstIndex(where: { $0.id == id }) else { return }
			graph.nodes[i].kind = kind
			// Drop wires into inputs the node no longer has (e.g. "is empty" takes one value).
			graph.links.removeAll { $0.to == id && !kind.inputs.contains($0.port) }
		}
	}

	/// The type of value a node produces, if known.
	func outputType(of nodeID: UUID, in graph: ConditionGraph) -> ConditionValueType? {
		guard let node = graph.node(nodeID) else { return nil }
		switch node.kind {
		case .control(let id): return project.find(id)?.kind.conditionValueType
		case .constant(.bool): return .bool
		case .constant(.number): return .number
		case .constant(.text): return .text
		case .not, .and, .or, .compare: return .bool
		case .visible: return nil
		}
	}

	/// Whether a wire from `from`'s output into `to`'s `port` makes sense: a real input, no loop,
	/// and comparisons between values of the same type.
	func canConnect(in windowID: UUID, from: UUID, to: UUID, port: String) -> Bool {
		guard from != to, let graph = project.window(windowID)?.conditions,
			let source = graph.node(from), source.kind.hasOutput,
			let target = graph.node(to), target.kind.inputs.contains(port)
		else { return false }
		// No loops: `to` mustn't already feed into `from`.
		var frontier = [to]
		var seen = Set<UUID>()
		while let current = frontier.popLast() {
			if current == from { return false }
			guard seen.insert(current).inserted else { continue }
			frontier += graph.links.filter { $0.from == current }.map(\.to)
		}
		if case .compare(let op) = target.kind {
			let type = outputType(of: from, in: graph)
			if op.isTextOnly && port == "a" && type != .text { return false }
			let otherPort = port == "a" ? "b" : "a"
			if let other = graph.links.first(where: { $0.to == to && $0.port == otherPort }),
				let otherType = outputType(of: other.from, in: graph), let type, otherType != type
			{
				return false
			}
		}
		return true
	}

	/// Wires `from` into `to`'s `port`, replacing whatever was plugged in there.
	func connectConditions(in windowID: UUID, from: UUID, to: UUID, port: String) {
		guard canConnect(in: windowID, from: from, to: to, port: port) else { return }
		editGraph(windowID) { graph in
			graph.links.removeAll { $0.to == to && $0.port == port }
			graph.links.append(ConditionLink(from: from, to: to, port: port))
		}
	}

	/// A component dropped onto the node editor: its value as a source if it's a control, or its
	/// visibility if not (reusing the node if there already is one).
	func addComponentNode(_ componentID: UUID, in windowID: UUID, at position: CGPoint) {
		guard let window = project.window(windowID), window.root.find(componentID) != nil,
			let component = project.find(componentID), componentID != window.root.id
		else { return }
		if component.kind.isConditionSource {
			addConditionNode(.control(componentID), in: windowID, at: position)
		} else if window.conditions.visibilityNode(for: componentID) == nil {
			addConditionNode(.visible(componentID), in: windowID, at: position)
		}
	}
}
