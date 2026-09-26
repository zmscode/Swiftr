import SwiftUI

// Inspector building blocks: dense 11pt type, borderless tinted fields that outline on
// hover and focus, scrubbable labels, icon segmented controls, and sections you add or remove with
// + and −.
enum PanelStyle {
	static let font = Font.system(size: 11)
	static let labelFont = Font.system(size: 11, weight: .medium)
	static let fieldHeight: CGFloat = 26
	static let radius: CGFloat = 5
	static let gutter: CGFloat = 8
	static var fieldFill: Color { Color.primary.opacity(0.055) }
}

/// The field chrome: tinted, borderless, outlined on hover (and in blue while focused).
struct PanelFieldChrome: ViewModifier {
	@Environment(\.panelTheme) private var panelTheme
	var focused = false
	@State private var isHovered = false

	func body(content: Content) -> some View {
		content
			.padding(.horizontal, 7)
			.frame(height: PanelStyle.fieldHeight)
			.background(
				RoundedRectangle(cornerRadius: PanelStyle.radius).fill(PanelStyle.fieldFill)
			)
			.overlay(
				RoundedRectangle(cornerRadius: PanelStyle.radius)
					.strokeBorder(
						focused ? panelTheme.accent : Color.primary.opacity(isHovered ? 0.14 : 0),
						lineWidth: focused ? 1.5 : 1)
			)
			.onHover { isHovered = $0 }
	}
}

extension View {
	func fieldChrome(focused: Bool = false) -> some View {
		modifier(PanelFieldChrome(focused: focused))
	}
}

enum PanelLabel {
	case letter(String)
	case icon(String)

	@ViewBuilder var view: some View {
		switch self {
		case .letter(let s):
			Text(s).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
		case .icon(let name):
			Image(systemName: name).font(.system(size: 10)).foregroundStyle(.secondary)
		}
	}
}

struct PanelSegmentLabel {
	var text: String? = nil
	var icon: String? = nil
	var help: String = ""

	static func text(_ t: String) -> PanelSegmentLabel { PanelSegmentLabel(text: t, help: t) }
	static func icon(_ i: String, _ help: String) -> PanelSegmentLabel {
		PanelSegmentLabel(icon: i, help: help)
	}

	@ViewBuilder var view: some View {
		if let icon { Image(systemName: icon) } else { Text(text ?? "") }
	}
}
