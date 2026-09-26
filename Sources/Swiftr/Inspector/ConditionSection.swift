import SwiftUI

/// "Visible when…": a component's condition in the inspector. Simple conditions (one control,
/// optionally compared with a value) are edited here; anything more involved is shown in words.
struct ConditionSection: View {
	let model: DesignModel
	let node: Node

	private var sources: [Node] { model.conditionSources(for: node.id) }

	var body: some View {
		if let condition = model.condition(for: node.id) {
			PanelSection("Condition", onRemove: { model.removeCondition(for: node.id) }) {
				if let simple = model.simpleCondition(for: node.id) {
					editor(simple)
					if let op = simple.op, let value = simple.value,
						let warning = model.neverTrueWarning(control: simple.source, op: op, value: value)
					{
						Label(warning, systemImage: "exclamationmark.triangle.fill")
							.font(PanelStyle.font)
							.foregroundStyle(.orange)
					}
				} else {
					PanelCaptioned("Visible when") {
						Text(model.describe(condition)).font(PanelStyle.font)
					}
				}
				PanelTextButton(
					title: "Open in Conditions", symbol: "point.3.connected.trianglepath.dotted",
					help: "Edit this window's conditions as a node graph (⌥⌘K)"
				) {
					model.windowManager?.showConditions(
						for: model.project.windowIndex(containing: node.id).map { model.project.windows[$0].id })
				}
			}
		} else if let first = sources.first {
			PanelSection("Condition", onAdd: { model.setCondition(model.defaultCondition(source: first), for: node.id) }) {
				EmptyView()
			}
		} else {
			PanelSection("Condition", collapsedByDefault: true) {
				PanelCaption("Add a toggle, slider, stepper, picker or text field to this window to show this only when it's set.")
			}
		}
	}

	@ViewBuilder
	private func editor(_ condition: SimpleCondition) -> some View {
		let source = model.project.find(condition.source)
		PanelCaptioned("Visible when") {
			PanelMenu(
				selection: Binding(
					get: { condition.source },
					set: { id in
						if let node = model.project.find(id) { model.setCondition(model.defaultCondition(source: node), for: self.node.id) }
					}),
				options: sources.map { ($0.id, model.controlName($0.id)) },
				help: "The control in this window whose value decides whether this shows")
		}
		if let source {
			switch source.kind.conditionValueType {
			case .bool?:
				PanelSegmented(
					selection: Binding(
						get: { condition.op == nil },
						set: { on in
							var c = condition
							c.op = on ? nil : .equal
							c.value = on ? nil : .bool(false)
							model.setCondition(c, for: node.id)
						}),
					items: [(true, .text("is on")), (false, .text("is off"))])
			case .number?:
				HStack(spacing: 6) {
					opMenu(condition, ops: [.equal, .notEqual, .less, .lessOrEqual, .greater, .greaterOrEqual])
						.frame(width: 64)
					if source.kind == .picker {
						PanelMenu(
							selection: valueBinding(condition, as: { .number(Double($0)) }, get: { Int($0?.number ?? 0) }),
							options: source.props.options.indices.map { ($0, source.props.options[$0]) },
							help: "The option the picker must be on")
					} else {
						PanelNumberField(
							label: .letter("="),
							value: valueBinding(condition, as: { .number($0) }, get: { $0?.number ?? 0 }),
							range: -100_000...100_000,
							step: source.kind == .slider
								? (source.props.sliderRange.upperBound - source.props.sliderRange.lowerBound) / 100 : 1,
							help: "The value to compare with")
					}
				}
			case .text?:
				opMenu(condition, ops: [.isNotEmpty, .isEmpty, .contains, .equal, .notEqual])
				if condition.op?.isBinary == true {
					PanelTextField(
						placeholder: "Text",
						text: valueBinding(condition, as: { .text($0) }, get: { $0?.text ?? "" }),
						help: "The text to compare with")
				}
			case nil:
				EmptyView()
			}
		}
	}

	private func opMenu(_ condition: SimpleCondition, ops: [CompareOp]) -> some View {
		PanelMenu(
			selection: Binding(
				get: { condition.op ?? ops[0] },
				set: { op in
					var c = condition
					c.op = op
					if !op.isBinary { c.value = nil } else if c.value == nil { c.value = op.isTextOnly ? .text("") : .number(0) }
					model.setCondition(c, for: node.id)
				}),
			options: ops.map { ($0, $0.symbol) }, help: "How to compare the control's value")
	}

	private func valueBinding<T>(
		_ condition: SimpleCondition, as make: @escaping (T) -> ConditionValue, get: @escaping (ConditionValue?) -> T
	) -> Binding<T> {
		Binding(
			get: { get(condition.value) },
			set: { value in
				var c = condition
				c.value = make(value)
				model.setCondition(c, for: node.id)
			})
	}
}
