import AppKit
import SwiftUI

/// The generated app, updating live as the design changes.
struct CodeView: View {
	@Environment(DesignModel.self) private var model
	@Environment(\.colorScheme) private var colorScheme
	@AppStorage(CodeTheme.storageKey) private var themeID = CodeTheme.automaticID
	@AppStorage("codeFontSize") private var fontSize = 12.0
	@State private var copied = false

	private var theme: CodeTheme { CodeTheme.resolve(themeID, dark: colorScheme == .dark) }

	var body: some View {
		let code = CodeGenerator.generate(model.project)
		let fileName = CodeGenerator.fileName(model.project)

		VStack(spacing: 0) {
			HStack(spacing: 10) {
				Image(systemName: "swift").foregroundStyle(.orange).font(.title2)
				VStack(alignment: .leading, spacing: 0) {
					Text(fileName).font(.headline)
					Text(
						"\(model.project.windows.count) window\(model.project.windows.count == 1 ? "" : "s") · \(CodeGenerator.minimumOS(model.project))+ · updates live"
					)
					.font(.caption).foregroundStyle(.secondary)
				}
				Spacer()
				themeMenu
				fontSizeControl
				Button {
					NSPasteboard.general.clearContents()
					NSPasteboard.general.setString(code, forType: .string)
					copied = true
				} label: {
					Label(
						copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc"
					)
				}
				Button("Save…") {
					FilePanels.save(code, suggestedName: fileName, type: .swiftSource)
				}
			}
			.padding(14)

			Divider()

			ScrollView([.vertical, .horizontal]) {
				HStack(alignment: .top, spacing: 14) {
					Text(Self.lineNumbers(code))
						.font(.system(size: fontSize, design: .monospaced))
						.foregroundStyle(theme.color(theme.lineNumber))
						.multilineTextAlignment(.trailing)
					Text(SwiftHighlighter.highlight(code, theme: theme, fontSize: fontSize))
						.textSelection(.enabled)
				}
				.lineSpacing(fontSize * 0.25)
				.padding(14)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.background(theme.color(theme.background))
			// Scroll bars and text selection follow the theme's brightness.
			.environment(\.colorScheme, theme.isDark ? .dark : .light)
		}
		.frame(minWidth: 620, minHeight: 360)
		.onChange(of: code) { copied = false }
	}

	private var themeMenu: some View {
		Menu {
			ThemeMenuContent()
		} label: {
			HStack(spacing: 6) {
				ThemePreview(theme: theme)
				Text(themeID == CodeTheme.automaticID ? "Automatic" : theme.name)
			}
		}
		.fixedSize()
		.help("Code theme")
	}

	private var fontSizeControl: some View {
		ControlGroup {
			Button {
				fontSize = max(9, fontSize - 1)
			} label: {
				Image(systemName: "textformat.size.smaller")
			}
			.help("Smaller text")
			Button {
				fontSize = min(24, fontSize + 1)
			} label: {
				Image(systemName: "textformat.size.larger")
			}
			.help("Larger text")
		}
		.fixedSize()
	}

	private static func lineNumbers(_ code: String) -> String {
		let count = code.split(separator: "\n", omittingEmptySubsequences: false).count
		return (1...max(count, 1)).map(String.init).joined(separator: "\n")
	}
}

/// A tiny swatch of a theme: its background with keyword, type and string colors.
struct ThemePreview: View {
	let theme: CodeTheme

	var body: some View {
		HStack(spacing: 2) {
			ForEach([theme.keyword, theme.type, theme.string], id: \.self) { hex in
				Circle().fill(theme.color(hex)).frame(width: 5, height: 5)
			}
		}
		.padding(.horizontal, 4)
		.frame(height: 14)
		.background(theme.color(theme.background), in: RoundedRectangle(cornerRadius: 3))
		.overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.2)))
	}
}
