import SwiftUI

/// Shown when nothing is selected: app-wide settings and the window list.
struct ProjectInspector: View {
	@Environment(DesignModel.self) private var model

	var body: some View {
		VStack(spacing: 0) {
			InspectorHeader(
				icon: "app.dashed", tint: .secondary, name: .constant(model.project.appName),
				editable: false,
				subtitle:
					"\(model.project.windows.count) window\(model.project.windows.count == 1 ? "" : "s")"
			) {
				EmptyView()
			}
			ScrollView {
				VStack(spacing: 0) {
					PanelSection("App") {
						PanelCaption("Name")
						PanelCommitField(
							placeholder: "App name", value: model.appNameBinding,
							help: "The app's name, used for its App struct. Press Return to apply")
					}
					PanelSection("Images") {
						if model.project.images.isEmpty {
							PanelCaption("Drag image files from Finder into a window to add them.")
						}
						ForEach(model.project.images) { asset in
							ImageAssetRow(asset: asset)
						}
						if !model.project.images.isEmpty {
							Button {
								model.exportImages()
							} label: {
								Label(
									"Export to Asset Catalog…", systemImage: "square.and.arrow.up"
								).font(PanelStyle.font)
							}
							.buttonStyle(.plain)
							.foregroundStyle(.secondary)
						}
					}
					PanelSection("Windows") {
						ForEach(model.project.windows) { window in
							HStack(spacing: 6) {
								Image(systemName: "macwindow").foregroundStyle(.secondary)
								Text(
									window.settings.title.isEmpty
										? window.viewName : window.settings.title)
								Spacer()
								Text(window.viewName).font(PanelStyle.font.monospaced())
									.foregroundStyle(.tertiary)
							}
							.frame(height: 22)
							.contentShape(Rectangle())
							.onTapGesture { model.select(window.root.id) }
						}
						Button {
							model.addWindow()
						} label: {
							Label("New Window", systemImage: "plus").font(PanelStyle.font)
						}
						.buttonStyle(.plain)
						.foregroundStyle(.secondary)
					}
					Text(
						"Select a component in a window, or a row in Layers, to edit it. Double-click text, symbols and shapes to edit them in place."
					)
					.font(PanelStyle.font)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(20)
				}
			}
		}
	}
}

/// One project image: thumbnail, editable name (used in `Image("name")`), usage, and delete.
struct ImageAssetRow: View {
	@Environment(DesignModel.self) private var model
	let asset: ImageAsset

	var body: some View {
		HStack(spacing: 8) {
			Group {
				if let image = model.nsImage(asset.id) {
					Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
				}
			}
			.frame(width: 26, height: 26)
			.clipShape(RoundedRectangle(cornerRadius: 4))
			PanelCommitField(
				value: Binding(get: { asset.name }, set: { model.renameImage(asset.id, to: $0) }),
				help: "The image's name in code, Image(\"name\"). Press Return to apply")
			let uses = model.project.usageCount(of: asset.id)
			Text(uses == 0 ? "unused" : "×\(uses)")
				.font(PanelStyle.font)
				.foregroundStyle(.tertiary)
			PanelIconButton(symbol: "minus", help: "Remove from project") {
				model.deleteImage(asset.id)
			}
		}
	}
}
