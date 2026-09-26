import SwiftUI

struct InspectorView: View {
	@Environment(DesignModel.self) private var model

	var body: some View {
		Group {
			if model.isPreviewing {
				ContentUnavailableView(
					"Previewing",
					systemImage: "play.fill",
					description: Text(
						"The windows behave like the finished app. Switch back to Edit (⌘R) to change them."
					)
				)
			} else if let node = model.selectedNode, let window = model.selectedWindow {
				NodeInspector(model: model, node: node, window: window)
					.id(node.id)
			} else {
				ProjectInspector()
			}
		}
		.font(PanelStyle.font)
	}
}

/// The inspector's top bar: icon, an editable name (the layer name, or the window title for a
/// window), what kind of thing it is, and actions.
struct InspectorHeader<Actions: View>: View {
	let icon: String
	let tint: Color
	@Binding var name: String
	var placeholder: String = ""
	var editable = true
	let subtitle: String
	@ViewBuilder let actions: Actions
	@FocusState private var editing: Bool

	var body: some View {
		HStack(spacing: 9) {
			Image(systemName: icon)
				.font(.system(size: 12, weight: .medium))
				.foregroundStyle(tint)
				.frame(width: 26, height: 26)
				.background(
					tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
			VStack(alignment: .leading, spacing: 1) {
				if editable {
					TextField(placeholder, text: $name)
						.textFieldStyle(.plain)
						.font(.system(size: 12, weight: .semibold))
						.focused($editing)
						.help("Rename")
				} else {
					Text(name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
				}
				Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
			}
			Spacer(minLength: 0)
			actions
		}
		.padding(.horizontal, 12)
		.frame(height: 52)
		.overlay(alignment: .bottom) {
			Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
		}
	}
}
