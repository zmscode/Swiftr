import FlowBridge
import SwiftFlow
import SwiftUI

// The node editor for a window's conditions. SwiftFlow draws and edits the graph; the graph itself
// lives in the model (`DesignWindow.conditions`), so it's saved, undoable and shared with the
// inspector's "Visible when…" shortcut. Only this folder imports SwiftFlow.

/// What each canvas node shows, derived from the model's `ConditionNode`.
struct ConditionCard: Equatable, Sendable {
	var kind: ConditionNodeKind
	var title: String
	var subtitle: String
	var icon: String
	var tint: ConditionTint
	var inputs: [ConditionPort]
	var output: ConditionValueType?
	/// Shown on the card, e.g. a comparison that can never be true.
	var warning: String? = nil
}

struct ConditionPort: Equatable, Sendable {
	var id: String
	var label: String
}

enum ConditionTint: Sendable { case source, value, logic, compare, effect }

extension ConditionValueType: @unchecked Sendable {}

struct ConditionsPanel: View {
	@Environment(DesignModel.self) private var model
	@Environment(\.panelTheme) private var panelTheme
	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var flow = SwiftFlowInstance()
	@State private var flowNodes: [FlowNode<ConditionCard>] = []
	@State private var flowEdges: [FlowEdge<EmptyEdgeData>] = []
	@State private var isDropTargeted = false

	var body: some View {
		VStack(spacing: 0) {
			header
			if let window = model.conditionsWindow {
				canvas(window)
			} else {
				ContentUnavailableView("No windows", systemImage: "macwindow")
			}
		}
	}

	// MARK: Header

	private var header: some View {
		HStack(spacing: 8) {
			PanelMenu(
				label: .icon("macwindow"),
				selection: Binding(
					get: { model.conditionsWindow?.id },
					set: { model.conditionsWindowID = $0 }),
				options: model.project.windows.map {
					($0.id, $0.settings.title.isEmpty ? $0.viewName : $0.settings.title)
				}
			)
			.frame(width: 180)
			if let window = model.conditionsWindow { addMenu(window) }
			PanelIconButton(
				symbol: "arrow.up.left.and.down.right.magnifyingglass", help: "Fit to view"
			) {
				flow.fitView(nodes: flowNodes, nodeSizes: flow.nodeSizes)
			}
			Spacer(minLength: 0)
			Text(
				"Drag controls and components here from Layers · connect outputs (right) to inputs (left)"
			)
			.font(PanelStyle.font)
			.foregroundStyle(.secondary)
			.lineLimit(1)
			.truncationMode(.head)
		}
		.padding(.horizontal, 10)
		.frame(height: 40)
		.overlay(alignment: .bottom) {
			Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
		}
	}

	private func addMenu(_ window: DesignWindow) -> some View {
		let sources = allNodes(in: window).filter { $0.kind.isConditionSource }
		let targets = allNodes(in: window).filter {
			$0.id != window.root.id && window.conditions.visibilityNode(for: $0.id) == nil
		}
		return Menu {
			Menu("Control Value") {
				ForEach(sources) { node in
					Button(model.controlName(node.id)) { add(.control(node.id), window) }
				}
			}
			.disabled(sources.isEmpty)
			Menu("Value") {
				Button("True / False") { add(.constant(.bool(true)), window) }
				Button("Number") { add(.constant(.number(0)), window) }
				Button("Text") { add(.constant(.text("")), window) }
			}
			Divider()
			Button("Not") { add(.not, window) }
			Button("And") { add(.and, window) }
			Button("Or") { add(.or, window) }
			Menu("Compare") {
				ForEach(CompareOp.allCases) { op in Button(op.symbol) { add(.compare(op), window) }
				}
			}
			Divider()
			Menu("Show Component") {
				ForEach(targets) { node in
					Button(node.displayName) { add(.visible(node.id), window) }
				}
			}
			.disabled(targets.isEmpty)
		} label: {
			Label("Add", systemImage: "plus").font(PanelStyle.font)
		}
		.fixedSize()
	}

	private func allNodes(in window: DesignWindow) -> [Node] {
		var nodes: [Node] = []
		var root = window.root
		root.forEach { nodes.append($0) }
		return nodes
	}

	/// New nodes go in the middle of what's visible.
	private func add(_ kind: ConditionNodeKind, _ window: DesignWindow) {
		let vp = flow.viewport
		let center = CGPoint(
			x: (flow.viewSize.width / 2 - vp.x) / vp.zoom - 90,
			y: (flow.viewSize.height / 2 - vp.y) / vp.zoom - 40)
		model.addConditionNode(kind, in: window.id, at: center)
	}

	// MARK: Canvas

	private func canvas(_ window: DesignWindow) -> some View {
		let cards = window.conditions.nodes.map {
			CardSnapshot(node: $0, card: card(for: $0, in: window))
		}
		return SwiftFlow(
			nodes: flowNodes,
			edges: flowEdges,
			onNodesChange: { changes in
				flowNodes = applyNodeChanges(changes, nodes: flowNodes)
				let removed = Set(
					changes.compactMap { change -> UUID? in
						if case .remove(let id) = change { return UUID(uuidString: id) }
						return nil
					})
				if !removed.isEmpty {
					model.deleteConditionItems(in: window.id, nodes: removed, links: [])
				}
			},
			onEdgesChange: { changes in
				flowEdges = applyEdgeChanges(changes, edges: flowEdges)
				let removed = Set(
					changes.compactMap { change -> UUID? in
						if case .remove(let id) = change { return UUID(uuidString: id) }
						return nil
					})
				if !removed.isEmpty {
					model.deleteConditionItems(in: window.id, nodes: [], links: removed)
				}
			},
			onConnect: { connection in
				guard let from = UUID(uuidString: connection.source),
					let to = UUID(uuidString: connection.target)
				else { return }
				model.connectConditions(
					in: window.id, from: from, to: to, port: connection.targetHandle ?? "in")
			},
			theme: flowTheme,
			colorMode: colorScheme == .dark ? .dark : .light,
			isValidConnection: { connection in
				guard let from = UUID(uuidString: connection.source),
					let to = UUID(uuidString: connection.target)
				else { return false }
				return model.canConnect(
					in: window.id, from: from, to: to, port: connection.targetHandle ?? "in")
			},
			onNodeDragStop: { _ in commitPositions(window) },
			onNodeDoubleClick: { node in revealComponent(node.data.kind) },
			swiftFlowInstance: flow,
			onSelectionDragStop: { _ in commitPositions(window) }
		) { node in
			ConditionNodeCard(node: node, windowID: window.id)
		} overlay: {
			Background(variant: .dots)
			Controls()
			MiniMap()
		}
		.overlay {
			if isDropTargeted {
				RoundedRectangle(cornerRadius: 4).strokeBorder(panelTheme.accent, lineWidth: 2)
					.allowsHitTesting(false)
			}
		}
		.onDrop(of: [.plainText], isTargeted: $isDropTargeted) { _, location in
			dropComponent(at: location, in: window)
		}
		.onAppear { sync(window, cards) }
		.onChange(of: cards) { sync(window, cards) }
		.onChange(of: window.id) { flow.fitView(nodes: flowNodes, nodeSizes: flow.nodeSizes) }
	}

	/// A component dragged in from Layers becomes a node where it's dropped.
	private func dropComponent(at location: CGPoint, in window: DesignWindow) -> Bool {
		guard let payload = model.draggingPayload, payload.hasPrefix("move:"),
			let id = UUID(uuidString: String(payload.dropFirst(5)))
		else { return false }
		model.draggingPayload = nil
		let vp = flow.viewport
		let position = CGPoint(x: (location.x - vp.x) / vp.zoom, y: (location.y - vp.y) / vp.zoom)
		model.addComponentNode(id, in: window.id, at: position)
		return true
	}

	/// Double-clicking a control or component node selects that component in its window.
	private func revealComponent(_ kind: ConditionNodeKind) {
		switch kind {
		case .control(let id), .visible(let id): model.select(id)
		default: break
		}
	}

	/// After dragging nodes, save where they ended up (one undo step).
	private func commitPositions(_ window: DesignWindow) {
		var moved: [UUID: CGPoint] = [:]
		for node in flowNodes {
			guard let id = UUID(uuidString: node.id), let saved = window.conditions.node(id) else {
				continue
			}
			let p = CGPoint(x: node.position.x, y: node.position.y)
			if p != saved.position { moved[id] = p }
		}
		if !moved.isEmpty { model.moveConditionNodes(in: window.id, to: moved) }
	}

	/// Rebuilds the canvas from the model, keeping what's selected.
	private func sync(_ window: DesignWindow, _ cards: [CardSnapshot]) {
		let selectedNodes = Set(flowNodes.filter(\.selected).map(\.id))
		flowNodes = cards.map { snapshot in
			var node = FlowNode(
				id: snapshot.node.id.uuidString,
				position: XYPosition(x: snapshot.node.position.x, y: snapshot.node.position.y),
				data: snapshot.card)
			node.selected = selectedNodes.contains(node.id)
			return node
		}
		let selectedEdges = Set(flowEdges.filter(\.selected).map(\.id))
		flowEdges = window.conditions.links.map { link in
			var edge = FlowEdge<EmptyEdgeData>(
				id: link.id.uuidString, source: link.from.uuidString, target: link.to.uuidString,
				sourceHandle: "out", targetHandle: link.port)
			edge.selected = selectedEdges.contains(edge.id)
			return edge
		}
	}

	private var flowTheme: SwiftFlowTheme {
		var theme = colorScheme == .dark ? SwiftFlowTheme.dark : SwiftFlowTheme.light
		theme.edgeSelectedColor = panelTheme.accent
		theme.nodeSelectedBorderColor = panelTheme.accent
		theme.selectionBoxColor = panelTheme.accent.opacity(0.1)
		theme.selectionBoxBorderColor = panelTheme.accent.opacity(0.5)
		theme.canvasBackgroundColor = .clear
		theme.gridColor = Color.primary.opacity(0.15)
		return theme
	}

	// MARK: Cards

	private func card(for node: ConditionNode, in window: DesignWindow) -> ConditionCard {
		func port(_ id: String, _ label: String) -> ConditionPort {
			ConditionPort(id: id, label: label)
		}
		switch node.kind {
		case .control(let id):
			let component = model.project.find(id)
			return ConditionCard(
				kind: node.kind, title: model.controlName(id),
				subtitle: component?.kind.displayName ?? "Missing",
				icon: component?.kind.symbol ?? "questionmark", tint: .source, inputs: [],
				output: component?.kind.conditionValueType)
		case .constant(let value):
			let type: ConditionValueType
			switch value {
			case .bool: type = .bool
			case .number: type = .number
			case .text: type = .text
			}
			return ConditionCard(
				kind: node.kind, title: "Value", subtitle: "", icon: "number", tint: .value,
				inputs: [], output: type)
		case .not:
			return ConditionCard(
				kind: node.kind, title: "Not", subtitle: "True when its input is false",
				icon: "exclamationmark",
				tint: .logic, inputs: [port("in", "Input")], output: .bool)
		case .and:
			return ConditionCard(
				kind: node.kind, title: "And", subtitle: "True when both are",
				icon: "circle.grid.cross",
				tint: .logic, inputs: [port("a", "A"), port("b", "B")], output: .bool)
		case .or:
			return ConditionCard(
				kind: node.kind, title: "Or", subtitle: "True when either is",
				icon: "circle.grid.cross.up.filled",
				tint: .logic, inputs: [port("a", "A"), port("b", "B")], output: .bool)
		case .compare(let op):
			return ConditionCard(
				kind: node.kind, title: "Compare", subtitle: "", icon: "equal", tint: .compare,
				inputs: op.isBinary
					? [port("a", "Value"), port("b", "Compared with")] : [port("a", "Value")],
				output: .bool,
				warning: model.neverTrueWarning(compareNode: node.id, in: window.conditions))
		case .visible(let id):
			let component = model.project.find(id)
			return ConditionCard(
				kind: node.kind, title: "Show \(component?.displayName ?? "Missing")",
				subtitle: "Visible while true", icon: component?.kind.symbol ?? "eye",
				tint: .effect,
				inputs: [port("in", "When")], output: nil)
		}
	}
}

/// A model node and how it's drawn, compared to know when the canvas needs rebuilding.
struct CardSnapshot: Equatable {
	let node: ConditionNode
	let card: ConditionCard
}
