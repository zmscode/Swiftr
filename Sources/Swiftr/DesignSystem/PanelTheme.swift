import AppKit
import SwiftUI

extension EnvironmentValues {
	/// The theme applied to the current tool panel, or nil when panels look native.
	@Entry var panelTheme: CodeTheme? = nil
}

extension CodeTheme {
	/// The panel accent: selection, focus rings, chosen items.
	var accent: Color { color(member) }

	/// Icon colors in themed panels: each family of components takes one of the theme's syntax colors.
	func color(for family: ComponentKind.Family) -> Color {
		switch family {
		case .control: color(member)
		case .shape: color(attribute)
		case .layout: color(keyword)
		case .group: color(type)
		case .navigation: color(string)
		}
	}
}

extension Optional where Wrapped == CodeTheme {
	/// The theme's accent, or the standard selection blue in native panels.
	var accent: Color { self?.accent ?? .selectionBlue }

	func tint(_ kind: ComponentKind) -> Color { self?.color(for: kind.family) ?? kind.tint }
}

extension CodeTheme {
	/// UserDefaults keys shared by the code window and the panels.
	static let storageKey = "codeThemeID"
	static let panelsKey = "themePanels"
}

/// Themes a tool panel (Library, Inspector) with the code theme: background, text, accent, the
/// light/dark appearance of its controls, and the panel window's own background and title bar.
/// With the Automatic theme, or panel theming turned off, panels look native.
struct ThemedPanel: ViewModifier {
	@AppStorage(CodeTheme.storageKey) private var themeID = CodeTheme.automaticID
	@AppStorage(CodeTheme.panelsKey) private var themePanels = true
	@Environment(\.colorScheme) private var colorScheme

	private var theme: CodeTheme? {
		guard themePanels, themeID != CodeTheme.automaticID else { return nil }
		return CodeTheme.resolve(themeID, dark: colorScheme == .dark)
	}

	func body(content: Content) -> some View {
		let theme = theme
		content
			.foregroundStyle(theme.map { $0.color($0.text) } ?? Color.primary)
			.tint(theme.map { $0.color($0.member) })
			.scrollContentBackground(theme == nil ? .automatic : .hidden)
			.background(theme.map { $0.color($0.background) } ?? Color.clear)
			.environment(\.colorScheme, theme.map { $0.isDark ? .dark : .light } ?? colorScheme)
			.environment(\.panelTheme, theme)
			.background(
				WindowConfigurator { window in
					if let theme {
						window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
						window.backgroundColor = theme.nsColor(theme.background)
						window.titlebarAppearsTransparent = true
					} else {
						window.appearance = nil
						window.backgroundColor = .windowBackgroundColor
						window.titlebarAppearsTransparent = false
					}
				}.id(theme?.id ?? "native"))
	}
}

/// Runs `configure` on the hosting window once the view is in one.
struct WindowConfigurator: NSViewRepresentable {
	let configure: (NSWindow) -> Void

	func makeNSView(context: Context) -> NSView { NSView() }

	func updateNSView(_ view: NSView, context: Context) {
		DispatchQueue.main.async {
			if let window = view.window { configure(window) }
		}
	}
}

/// The theme choices, shared by the code window's theme menu and the Library's.
struct ThemeMenuContent: View {
	@AppStorage(CodeTheme.storageKey) private var themeID = CodeTheme.automaticID
	@AppStorage(CodeTheme.panelsKey) private var themePanels = true

	var body: some View {
		Button {
			themeID = CodeTheme.automaticID
		} label: {
			item("Automatic (Xcode)", selected: themeID == CodeTheme.automaticID)
		}
		Divider()
		Section("Dark") {
			ForEach(CodeTheme.all.filter(\.isDark)) { t in
				Button {
					themeID = t.id
				} label: {
					item(t.name, selected: themeID == t.id)
				}
			}
		}
		Section("Light") {
			ForEach(CodeTheme.all.filter { !$0.isDark }) { t in
				Button {
					themeID = t.id
				} label: {
					item(t.name, selected: themeID == t.id)
				}
			}
		}
		Divider()
		Toggle("Theme Library & Inspector", isOn: $themePanels)
	}

	@ViewBuilder
	private func item(_ name: String, selected: Bool) -> some View {
		if selected { Label(name, systemImage: "checkmark") } else { Text(name) }
	}
}
