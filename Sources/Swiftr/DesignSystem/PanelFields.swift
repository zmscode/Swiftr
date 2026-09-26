import AppKit
import SwiftUI

/// Leading icon or letter inside a field. Drag it horizontally to scrub a number.
struct PanelScrubLabel: View {
	let label: PanelLabel
	@Binding var value: Double
	var range: ClosedRange<Double>
	var step: Double = 1
	@State private var start: Double?

	var body: some View {
		label.view
			.frame(minWidth: 14)
			.contentShape(Rectangle())
			.onHover { inside in
				if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
			}
			.gesture(
				DragGesture(minimumDistance: 1)
					.onChanged { drag in
						let s = start ?? value
						start = s
						value = (s + (drag.translation.width / 2).rounded() * step).clamped(
							to: range)
					}
					.onEnded { _ in start = nil }
			)
	}
}

struct PanelNumberField: View {
	let label: PanelLabel
	@Binding var value: Double
	var range: ClosedRange<Double> = 0...10_000
	var step: Double = 1
	var unit: String? = nil
	var help: String = ""
	@FocusState private var focused: Bool

	var body: some View {
		HStack(spacing: 6) {
			PanelScrubLabel(label: label, value: $value, range: range, step: step)
			TextField(
				"", value: Binding(get: { value }, set: { value = $0.clamped(to: range) }),
				format: .number.precision(.fractionLength(0...2))
			)
			.textFieldStyle(.plain)
			.font(PanelStyle.font.monospacedDigit())
			.focused($focused)
			if let unit { Text(unit).font(PanelStyle.font).foregroundStyle(.tertiary) }
		}
		.fieldChrome(focused: focused)
		.help(help)
	}
}

/// A 0...1 value shown and edited as a percentage.
struct PanelPercentField: View {
	let label: PanelLabel
	@Binding var value: Double
	var help: String = ""

	var body: some View {
		PanelNumberField(
			label: label,
			value: Binding(get: { (value * 100).rounded() }, set: { value = $0 / 100 }),
			range: 0...100, unit: "%", help: help)
	}
}

struct PanelTextField: View {
	@Environment(\.panelTheme) private var panelTheme
	var placeholder = ""
	@Binding var text: String
	var monospaced = false
	var multiline = false
	@FocusState private var focused: Bool

	var body: some View {
		Group {
			if multiline {
				TextField(placeholder, text: $text, axis: .vertical)
					.lineLimit(1...6)
					.padding(.vertical, 5)
			} else {
				TextField(placeholder, text: $text)
			}
		}
		.textFieldStyle(.plain)
		.font(monospaced ? PanelStyle.font.monospaced() : PanelStyle.font)
		.focused($focused)
		.padding(.horizontal, 7)
		.frame(minHeight: PanelStyle.fieldHeight)
		.background(RoundedRectangle(cornerRadius: PanelStyle.radius).fill(PanelStyle.fieldFill))
		.overlay(
			RoundedRectangle(cornerRadius: PanelStyle.radius)
				.strokeBorder(focused ? panelTheme.accent : .clear, lineWidth: 1.5))
	}
}

/// A text field that writes back only when editing ends, for values that get normalized (like
/// Swift names), where rewriting mid-typing would fight the user.
struct PanelCommitField: View {
	var placeholder = ""
	@Binding var value: String
	var monospaced = true
	@State private var draft = ""

	var body: some View {
		PanelTextField(placeholder: placeholder, text: $draft, monospaced: monospaced)
			.onAppear { draft = value }
			.onChange(of: value) { _, new in draft = new }
			.onSubmit {
				value = draft
				draft = value
			}
	}
}

/// A menu that looks like a field: current value on the left, chevron on the right.
struct PanelMenu<Value: Hashable>: View {
	var label: PanelLabel? = nil
	@Binding var selection: Value
	let options: [(value: Value, title: String)]

	var body: some View {
		Menu {
			ForEach(options, id: \.value) { option in
				Button {
					selection = option.value
				} label: {
					if option.value == selection {
						Label(option.title, systemImage: "checkmark")
					} else {
						Text(option.title)
					}
				}
			}
		} label: {
			HStack(spacing: 6) {
				if let label { label.view }
				Text(options.first { $0.value == selection }?.title ?? "—")
					.font(PanelStyle.font)
					.foregroundStyle(.primary)
					.lineLimit(1)
				Spacer(minLength: 0)
				Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
					.foregroundStyle(.secondary)
			}
			.fieldChrome()
			.contentShape(Rectangle())
		}
		.menuStyle(.button)
		.buttonStyle(.plain)
		.menuIndicator(.hidden)
	}
}

/// Segmented control: a tinted track with a raised selected segment.
struct PanelSegmented<Value: Hashable>: View {
	@Binding var selection: Value
	let items: [(value: Value, label: PanelSegmentLabel)]

	var body: some View {
		HStack(spacing: 2) {
			ForEach(items, id: \.value) { item in
				let isSelected = item.value == selection
				Button {
					selection = item.value
				} label: {
					item.label.view
						.font(.system(size: 11, weight: isSelected ? .medium : .regular))
						.foregroundStyle(isSelected ? .primary : .secondary)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.background(
							RoundedRectangle(cornerRadius: 4)
								.fill(isSelected ? Color(nsColor: .controlBackgroundColor) : .clear)
								.shadow(
									color: .black.opacity(isSelected ? 0.15 : 0), radius: 1, y: 0.5)
						)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.help(item.label.help)
			}
		}
		.padding(2)
		.frame(height: PanelStyle.fieldHeight)
		.background(RoundedRectangle(cornerRadius: PanelStyle.radius).fill(PanelStyle.fieldFill))
	}
}

struct PanelCheckbox: View {
	let title: String
	@Binding var isOn: Bool
	var help: String = ""

	var body: some View {
		Toggle(isOn: $isOn) { Text(title).font(PanelStyle.font) }
			.toggleStyle(.checkbox)
			.controlSize(.small)
			.help(help)
	}
}
