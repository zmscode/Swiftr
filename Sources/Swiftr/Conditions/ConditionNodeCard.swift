import FlowBridge
import SwiftFlow
import SwiftUI

/// One node in the Conditions panel: a card with its inputs on the left, its output on the right,
/// and inline controls for values and operators.
struct ConditionNodeCard: View {
	@Environment(DesignModel.self) private var model
	@Environment(\.panelTheme) private var panelTheme
	let node: FlowNode<ConditionCard>
	let windowID: UUID

	private var card: ConditionCard { node.data }
	private var id: UUID? { UUID(uuidString: node.id) }

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
			VStack(alignment: .leading, spacing: 6) {
				editor
				ForEach(card.inputs, id: \.id) { port in
					HStack(spacing: 6) {
						Handle(
							nodeId: node.id, id: port.id, type: .target, position: .left,
							color: .gray
						)
						.offset(x: -16)
						.padding(.trailing, -16)
						Text(port.label).font(.system(size: 10)).foregroundStyle(.secondary)
					}
				}
				if let output = card.output {
					HStack(spacing: 6) {
						Spacer(minLength: 0)
						Text(outputLabel(output)).font(.system(size: 10)).foregroundStyle(
							.secondary)
						Handle(
							nodeId: node.id, id: "out", type: .source, position: .right,
							color: color(for: output)
						)
						.offset(x: 16)
						.padding(.leading, -16)
					}
				}
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 8)
		}
		.frame(width: 200)
		.background(
			RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 10)
				.strokeBorder(
					node.selected ? panelTheme.accent : Color.primary.opacity(0.15),
					lineWidth: node.selected ? 2 : 1)
		)
		.shadow(color: .black.opacity(0.15), radius: 4, y: 2)
	}

	private var header: some View {
		HStack(spacing: 6) {
			Image(systemName: card.icon)
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 18, height: 18)
				.background(RoundedRectangle(cornerRadius: 4).fill(tint))
			VStack(alignment: .leading, spacing: 0) {
				Text(card.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
				if !card.subtitle.isEmpty {
					Text(card.subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.background(
			tint.opacity(0.12),
			in: UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))
	}

	// MARK: Inline editors

	@ViewBuilder
	private var editor: some View {
		switch card.kind {
		case .constant(let value):
			constantEditor(value)
		case .compare(let op):
			Picker("", selection: Binding(get: { op }, set: { update(.compare($0)) })) {
				ForEach(CompareOp.allCases) { Text($0.symbol).tag($0) }
			}
			.labelsHidden()
			.controlSize(.small)
		case .control(let controlID):
			let sources = model.conditionSources(inWindow: windowID)
			Picker("", selection: Binding(get: { controlID }, set: { update(.control($0)) })) {
				ForEach(sources) { Text(model.controlName($0.id)).tag($0.id) }
			}
			.labelsHidden()
			.controlSize(.small)
		default:
			EmptyView()
		}
	}

	@ViewBuilder
	private func constantEditor(_ value: ConditionValue) -> some View {
		HStack(spacing: 6) {
			switch value {
			case .bool(let b):
				Toggle("", isOn: Binding(get: { b }, set: { update(.constant(.bool($0))) }))
					.toggleStyle(.switch)
					.labelsHidden()
				Text(b ? "true" : "false").font(.system(size: 11, design: .monospaced))
			case .number(let n):
				TextField(
					"0", value: Binding(get: { n }, set: { update(.constant(.number($0))) }),
					format: .number
				)
				.textFieldStyle(.roundedBorder)
			case .text(let t):
				TextField("Text", text: Binding(get: { t }, set: { update(.constant(.text($0))) }))
					.textFieldStyle(.roundedBorder)
			}
			Menu {
				Button("True / False") { update(.constant(.bool(value.bool))) }
				Button("Number") { update(.constant(.number(value.number))) }
				Button("Text") { update(.constant(.text(value.text))) }
			} label: {
				Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
			}
			.menuStyle(.button)
			.buttonStyle(.plain)
			.menuIndicator(.hidden)
			.fixedSize()
			.help("Value type")
		}
		.controlSize(.small)
	}

	private func update(_ kind: ConditionNodeKind) {
		guard let id else { return }
		model.updateConditionNode(in: windowID, id, to: kind)
	}

	// MARK: Styling

	private var tint: Color {
		switch card.tint {
		case .source: .blue
		case .value: .gray
		case .logic: .purple
		case .compare: .teal
		case .effect: .orange
		}
	}

	private func color(for type: ConditionValueType) -> Color {
		switch type {
		case .bool: .green
		case .number: .blue
		case .text: .orange
		}
	}

	private func outputLabel(_ type: ConditionValueType) -> String {
		switch type {
		case .bool: "true / false"
		case .number: "number"
		case .text: "text"
		}
	}
}
