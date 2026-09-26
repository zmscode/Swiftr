import SwiftUI

/// Swiftr → Settings… (⌘,).
struct SettingsView: View {
	enum Launch: String, CaseIterable, Identifiable {
		case empty, reopenLast
		var id: String { rawValue }
	}

	static let launchKey = "launchBehavior"

	var body: some View {
		TabView {
			Tab("General", systemImage: "gearshape") { GeneralSettings() }
			Tab("Appearance", systemImage: "paintpalette") { AppearanceSettings() }
			Tab("Export", systemImage: "square.and.arrow.up") { ExportSettings() }
		}
		.frame(width: 480)
	}
}

private struct GeneralSettings: View {
	@AppStorage(SettingsView.launchKey) private var launch = SettingsView.Launch.empty.rawValue

	var body: some View {
		Form {
			Picker("When Swiftr opens", selection: $launch) {
				Text("Start an empty project").tag(SettingsView.Launch.empty.rawValue)
				Text("Reopen the last project").tag(SettingsView.Launch.reopenLast.rawValue)
			}
			.pickerStyle(.radioGroup)
			Text(
				"Opening a file from the command line (`swift run Swiftr MyApp.json`) always opens that file."
			)
			.font(.caption)
			.foregroundStyle(.secondary)
		}
		.formStyle(.grouped)
	}
}

private struct AppearanceSettings: View {
	@AppStorage(CodeTheme.storageKey) private var themeID = CodeTheme.automaticID
	@AppStorage(CodeTheme.panelsKey) private var themePanels = true

	var body: some View {
		Form {
			Picker("Theme", selection: $themeID) {
				Text("Automatic (Xcode)").tag(CodeTheme.automaticID)
				Section("Dark") {
					ForEach(CodeTheme.all.filter(\.isDark)) { Text($0.name).tag($0.id) }
				}
				Section("Light") {
					ForEach(CodeTheme.all.filter { !$0.isDark }) { Text($0.name).tag($0.id) }
				}
			}
			Toggle("Theme the Library, Inspector and Conditions panels", isOn: $themePanels)
				.disabled(themeID == CodeTheme.automaticID)
			Text(
				"The theme colors the generated code. With panel theming on, it also colors the panels; Automatic keeps them native."
			)
			.font(.caption)
			.foregroundStyle(.secondary)
		}
		.formStyle(.grouped)
	}
}

private struct ExportSettings: View {
	@AppStorage(CodeExportOptions.Key.layout) private var layout = CodeExportOptions.Layout
		.singleFile.rawValue
	@AppStorage(CodeExportOptions.Key.viewsFolder) private var viewsFolder = "Views"
	@AppStorage(CodeExportOptions.Key.includePreviews) private var includePreviews = true
	@AppStorage(CodeExportOptions.Key.indent) private var indent = CodeExportOptions.Indent
		.fourSpaces.rawValue
	@Environment(DesignModel.self) private var model

	var body: some View {
		Form {
			Section("Export as Swift (⇧⌘E)") {
				Picker("Layout", selection: $layout) {
					Text("One file").tag(CodeExportOptions.Layout.singleFile.rawValue)
					Text("A file per view").tag(CodeExportOptions.Layout.folder.rawValue)
				}
				.pickerStyle(.radioGroup)
				if layout == CodeExportOptions.Layout.folder.rawValue {
					TextField("Views folder", text: $viewsFolder)
				}
				Toggle("Include #Preview blocks", isOn: $includePreviews)
				Picker("Indentation", selection: $indent) {
					Text("4 spaces").tag(CodeExportOptions.Indent.fourSpaces.rawValue)
					Text("2 spaces").tag(CodeExportOptions.Indent.twoSpaces.rawValue)
					Text("Tabs").tag(CodeExportOptions.Indent.tabs.rawValue)
				}
			}
			Section("Produces") {
				Text(layoutPreview)
					.font(.system(.caption, design: .monospaced))
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
			}
		}
		.formStyle(.grouped)
	}

	/// The files an export would write, for the current project.
	private var layoutPreview: String {
		let options = CodeExportOptions.current
		guard options.layout == .folder else { return CodeGenerator.fileName(model.project) }
		return CodeGenerator.files(model.project, options: options).map(\.path).joined(
			separator: "\n")
	}
}
