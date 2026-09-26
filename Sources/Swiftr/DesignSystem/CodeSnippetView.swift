import AppKit
import SwiftUI

/// A few lines of Swift in the current code theme, with a copy button.
struct CodeSnippetView: View {
	let code: String
	@AppStorage(CodeTheme.storageKey) private var themeID = CodeTheme.automaticID
	@Environment(\.colorScheme) private var colorScheme
	@State private var copied = false

	var body: some View {
		let theme = CodeTheme.resolve(themeID, dark: colorScheme == .dark)
		ScrollView(.horizontal) {
			Text(SwiftHighlighter.highlight(code, theme: theme, fontSize: 10.5))
				.textSelection(.enabled)
				.lineSpacing(2)
				.padding(10)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(theme.color(theme.background), in: RoundedRectangle(cornerRadius: 6))
		.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.08)))
		.overlay(alignment: .topTrailing) {
			PanelIconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy") {
				NSPasteboard.general.clearContents()
				NSPasteboard.general.setString(code, forType: .string)
				copied = true
			}
			.padding(4)
		}
		.onChange(of: code) { copied = false }
	}
}
