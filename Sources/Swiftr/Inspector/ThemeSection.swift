import SwiftUI

/// The project's colour scheme and shared Liquid Glass look: the Theme tab.
struct ThemeSection: View {
	@Environment(DesignModel.self) private var model

	private var theme: ProjectTheme { model.project.theme }

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			PanelCaptioned("Scheme") {
				PanelMenu(
					selection: Binding(
						get: { theme.preset?.id ?? "custom" },
						set: { id in ThemePreset(rawValue: id).map(model.applyThemePreset) }),
					options: ThemePreset.allCases.map { ($0.id, $0.title) }
						+ (theme.preset == nil ? [("custom", "Custom")] : []),
					help: "A ready-made accent and palette; glass settings are kept")
			}
			PanelCaptioned("Accent") {
				if let accent = theme.accent {
					PanelColorRow(
						color: Binding(
							get: { accent }, set: { model.themeBinding(\.accent).wrappedValue = $0 }
						),
						onRemove: { model.themeBinding(\.accent).wrappedValue = nil })
				} else {
					PanelTextButton(
						title: "System accent", symbol: "plus",
						help:
							"Every control uses the system accent. Click to choose one for the app"
					) {
						model.themeBinding(\.accent).wrappedValue = RGBA(
							Color(nsColor: .controlAccentColor))
					}
				}
			}
			PanelCaptioned("Palette") {
				ForEach(theme.palette.indices, id: \.self) { i in
					PanelColorRow(
						color: Binding(
							get: { model.project.theme.palette[safe: i] ?? .black },
							set: { model.themeBinding(\.palette[i]).wrappedValue = $0 }),
						onRemove: {
							var palette = theme.palette
							palette.remove(at: i)
							model.themeBinding(\.palette).wrappedValue = palette
						})
				}
				PanelTextButton(
					title: "Add colour", symbol: "plus",
					help: "Scheme colours show first in every colour picker"
				) {
					model.themeBinding(\.palette).wrappedValue =
						theme.palette + [theme.accent ?? .blue]
				}
			}
			glass
		}
		.padding(10)
		.font(PanelStyle.font)
	}

	@ViewBuilder
	private var glass: some View {
		PanelCaptioned("Liquid Glass") {
			PanelSegmented(
				selection: model.themeBinding(\.glass.variant),
				items: [(.regular, .text("Regular")), (.clear, .text("Clear"))])
			PanelSegmented(
				selection: model.themeBinding(\.glass.tintSource),
				items: [
					(.none, PanelSegmentLabel(text: "No tint", help: "Plain glass")),
					(.accent, PanelSegmentLabel(text: "Accent", help: "Tinted with the accent")),
					(
						.custom,
						PanelSegmentLabel(text: "Custom", help: "Tinted with a colour of your own")
					),
				])
			if theme.glass.tintSource == .custom {
				PanelColorRow(color: model.themeBinding(\.glass.customTint))
			}
			PanelCheckbox(
				title: "Interactive", isOn: model.themeBinding(\.glass.interactive),
				help: "Glass reacts to touch and pointer, like system glass controls")
		}
		PanelCaption("Applies to glass set to “Follow project theme”.")
	}
}

extension Array {
	subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
