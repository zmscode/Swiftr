import SwiftUI

// Conditions decide which components show, from the values of controls in the same window.
// They're a small graph: sources (a control's value, a constant) feed logic (not, and, or,
// compare), which feeds a "visible" effect on a component. The node editor edits this graph
// directly; generated code turns it into `if` statements over `@State` variables.

/// A value flowing through a condition graph.
enum ConditionValue: Codable, Equatable, Hashable {
	case bool(Bool)
	case number(Double)
	case text(String)

	var bool: Bool {
		switch self {
		case .bool(let b): b
		case .number(let n): n != 0
		case .text(let t): !t.isEmpty
		}
	}

	var number: Double {
		switch self {
		case .bool(let b): b ? 1 : 0
		case .number(let n): n
		case .text(let t): Double(t) ?? 0
		}
	}

	var text: String {
		switch self {
		case .bool(let b): b ? "true" : "false"
		case .number(let n): CodeGenerator.number(n)
		case .text(let t): t
		}
	}
}

enum CompareOp: String, Codable, CaseIterable, Identifiable {
	case equal, notEqual, less, lessOrEqual, greater, greaterOrEqual, contains, isEmpty, isNotEmpty
	var id: String { rawValue }

	/// Whether the operator takes a second value to compare against.
	var isBinary: Bool { self != .isEmpty && self != .isNotEmpty }
	var isTextOnly: Bool { [.contains, .isEmpty, .isNotEmpty].contains(self) }

	var symbol: String {
		switch self {
		case .equal: "="
		case .notEqual: "≠"
		case .less: "<"
		case .lessOrEqual: "≤"
		case .greater: ">"
		case .greaterOrEqual: "≥"
		case .contains: "contains"
		case .isEmpty: "is empty"
		case .isNotEmpty: "is not empty"
		}
	}
}

enum ConditionNodeKind: Codable, Equatable {
	/// The current value of a control (toggle, slider, stepper, picker, text field…).
	case control(UUID)
	case constant(ConditionValue)
	case not
	case and
	case or
	case compare(CompareOp)
	/// The component shows only while its input is true.
	case visible(UUID)

	/// The named inputs this kind of node takes.
	var inputs: [String] {
		switch self {
		case .control, .constant: []
		case .not, .visible: ["in"]
		case .and, .or: ["a", "b"]
		case .compare(let op): op.isBinary ? ["a", "b"] : ["a"]
		}
	}

	var hasOutput: Bool {
		if case .visible = self { return false }
		return true
	}
}

struct ConditionNode: Identifiable, Codable, Equatable {
	var id = UUID()
	var kind: ConditionNodeKind
	/// Where the node sits in the node editor.
	var position = CGPoint.zero
}

/// A wire from one node's output to another node's named input.
struct ConditionLink: Identifiable, Codable, Equatable {
	var id = UUID()
	var from: UUID
	var to: UUID
	var port: String
}

/// A condition as an expression, built by following the graph back from a component's
/// "visible" node.
indirect enum ConditionExpr: Equatable {
	case control(UUID)
	case constant(ConditionValue)
	case not(ConditionExpr)
	case and(ConditionExpr, ConditionExpr)
	case or(ConditionExpr, ConditionExpr)
	case compare(CompareOp, ConditionExpr, ConditionExpr?)
}

struct ConditionGraph: Codable, Equatable {
	var nodes: [ConditionNode] = []
	var links: [ConditionLink] = []

	var isEmpty: Bool { nodes.isEmpty }

	func node(_ id: UUID) -> ConditionNode? { nodes.first { $0.id == id } }

	/// The "visible" node for a component, if it has one.
	func visibilityNode(for componentID: UUID) -> ConditionNode? {
		nodes.first { $0.kind == .visible(componentID) }
	}

	/// The condition deciding whether a component shows, or nil if it has none (or it's
	/// incomplete, e.g. an unconnected input — then the component simply always shows).
	func condition(for componentID: UUID) -> ConditionExpr? {
		guard let visible = visibilityNode(for: componentID) else { return nil }
		var visiting = Set<UUID>()
		return input(of: visible.id, "in", visiting: &visiting)
	}

	private func input(of nodeID: UUID, _ port: String, visiting: inout Set<UUID>) -> ConditionExpr? {
		guard let link = links.first(where: { $0.to == nodeID && $0.port == port }) else { return nil }
		return expression(at: link.from, visiting: &visiting)
	}

	private func expression(at nodeID: UUID, visiting: inout Set<UUID>) -> ConditionExpr? {
		// A loop can't produce a value.
		guard let node = node(nodeID), visiting.insert(nodeID).inserted else { return nil }
		defer { visiting.remove(nodeID) }
		switch node.kind {
		case .control(let id): return .control(id)
		case .constant(let value): return .constant(value)
		case .not:
			return input(of: nodeID, "in", visiting: &visiting).map { .not($0) }
		case .and, .or:
			guard let a = input(of: nodeID, "a", visiting: &visiting),
				let b = input(of: nodeID, "b", visiting: &visiting)
			else { return nil }
			return node.kind == .and ? .and(a, b) : .or(a, b)
		case .compare(let op):
			guard let a = input(of: nodeID, "a", visiting: &visiting) else { return nil }
			if op.isBinary {
				guard let b = input(of: nodeID, "b", visiting: &visiting) else { return nil }
				return .compare(op, a, b)
			}
			return .compare(op, a, nil)
		case .visible: return nil
		}
	}

	/// Removes everything about a component (as a source or a target) and the wires to it.
	mutating func removeReferences(to componentIDs: Set<UUID>) {
		let doomed = Set(nodes.filter { node in
			switch node.kind {
			case .control(let id), .visible(let id): componentIDs.contains(id)
			default: false
			}
		}.map(\.id))
		guard !doomed.isEmpty else { return }
		nodes.removeAll { doomed.contains($0.id) }
		links.removeAll { doomed.contains($0.from) || doomed.contains($0.to) }
	}

	/// Removes a component's visibility condition and any nodes only it used.
	mutating func removeCondition(for componentID: UUID) {
		guard let visible = visibilityNode(for: componentID) else { return }
		var doomed: Set<UUID> = [visible.id]
		// Walk upstream; drop nodes that feed nothing else.
		var frontier = [visible.id]
		while let current = frontier.popLast() {
			for link in links where link.to == current {
				let feedsOthers = links.contains { $0.from == link.from && !doomed.contains($0.to) && $0.to != current }
				if !feedsOthers && doomed.insert(link.from).inserted { frontier.append(link.from) }
			}
		}
		nodes.removeAll { doomed.contains($0.id) }
		links.removeAll { doomed.contains($0.from) || doomed.contains($0.to) }
	}
}

extension ComponentKind {
	/// Controls whose value conditions can read.
	var isConditionSource: Bool {
		[.toggle, .slider, .stepper, .picker, .textField, .secureField, .textEditor].contains(self)
	}

	/// The kind of value a control provides.
	var conditionValueType: ConditionValueType? {
		switch self {
		case .toggle: .bool
		case .slider, .stepper, .picker: .number
		case .textField, .secureField, .textEditor: .text
		default: nil
		}
	}
}

enum ConditionValueType { case bool, number, text }
