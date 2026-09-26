import AppKit
import SwiftUI

/// Colors for the code window. Palettes are approximations of each editor theme's Swift colors.
struct CodeTheme: Identifiable, Hashable {
	let id: String
	let name: String
	let isDark: Bool
	let background: String
	let text: String
	let lineNumber: String
	let keyword: String
	let type: String
	let member: String
	let number: String
	let string: String
	let comment: String
	let attribute: String
	var boldKeywords = false

	func color(_ hex: String) -> Color { Color(nsColor: nsColor(hex)) }

	func nsColor(_ hex: String) -> NSColor {
		let v = Int(hex.dropFirst(), radix: 16) ?? 0
		return NSColor(
			srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
			blue: CGFloat(v & 0xFF) / 255, alpha: 1)
	}

	/// Follows the system appearance: Xcode Dark or Xcode Light.
	static let automaticID = "automatic"

	static func resolve(_ id: String, dark: Bool) -> CodeTheme {
		if id == automaticID { return dark ? xcodeDark : xcodeLight }
		return all.first { $0.id == id } ?? (dark ? xcodeDark : xcodeLight)
	}

	static let xcodeDark = CodeTheme(
		id: "xcode-dark", name: "Xcode Dark", isDark: true,
		background: "#1F1F24", text: "#DFDFE0", lineNumber: "#747478",
		keyword: "#FC5FA3", type: "#D0A8FF", member: "#A167E6", number: "#D0BF69",
		string: "#FC6A5D", comment: "#7F8C98", attribute: "#FD8F3F", boldKeywords: true)

	static let xcodeLight = CodeTheme(
		id: "xcode-light", name: "Xcode Light", isDark: false,
		background: "#FFFFFF", text: "#000000", lineNumber: "#A6A6A6",
		keyword: "#9B2393", type: "#3900A0", member: "#326D74", number: "#1C00CF",
		string: "#C41A16", comment: "#5D6C79", attribute: "#643820", boldKeywords: true)

	static let githubDark = CodeTheme(
		id: "github-dark", name: "GitHub Dark", isDark: true,
		background: "#0D1117", text: "#E6EDF3", lineNumber: "#6E7681",
		keyword: "#FF7B72", type: "#FFA657", member: "#D2A8FF", number: "#79C0FF",
		string: "#A5D6FF", comment: "#8B949E", attribute: "#FF7B72")

	static let githubLight = CodeTheme(
		id: "github-light", name: "GitHub Light", isDark: false,
		background: "#FFFFFF", text: "#1F2328", lineNumber: "#8C959F",
		keyword: "#CF222E", type: "#953800", member: "#8250DF", number: "#0550AE",
		string: "#0A3069", comment: "#6E7781", attribute: "#CF222E")

	static let gruvboxDark = CodeTheme(
		id: "gruvbox-dark", name: "Gruvbox Dark", isDark: true,
		background: "#282828", text: "#EBDBB2", lineNumber: "#7C6F64",
		keyword: "#FB4934", type: "#FABD2F", member: "#8EC07C", number: "#D3869B",
		string: "#B8BB26", comment: "#928374", attribute: "#FE8019")

	static let gruvboxLight = CodeTheme(
		id: "gruvbox-light", name: "Gruvbox Light", isDark: false,
		background: "#FBF1C7", text: "#3C3836", lineNumber: "#A89984",
		keyword: "#9D0006", type: "#B57614", member: "#427B58", number: "#8F3F71",
		string: "#79740E", comment: "#928374", attribute: "#AF3A03")

	static let x96f = CodeTheme(
		id: "0x96f", name: "0x96f", isDark: true,
		background: "#262427", text: "#FCFCFA", lineNumber: "#6E6A70",
		keyword: "#FF7272", type: "#49CAE4", member: "#A093E2", number: "#FFCA58",
		string: "#BCDF59", comment: "#8B888F", attribute: "#FC9D6F")

	static let darcula = CodeTheme(
		id: "darcula", name: "Darcula", isDark: true,
		background: "#2B2B2B", text: "#A9B7C6", lineNumber: "#606366",
		keyword: "#CC7832", type: "#A9B7C6", member: "#FFC66D", number: "#6897BB",
		string: "#6A8759", comment: "#808080", attribute: "#BBB529")

	static let dracula = CodeTheme(
		id: "dracula", name: "Dracula", isDark: true,
		background: "#282A36", text: "#F8F8F2", lineNumber: "#6272A4",
		keyword: "#FF79C6", type: "#8BE9FD", member: "#50FA7B", number: "#BD93F9",
		string: "#F1FA8C", comment: "#6272A4", attribute: "#FFB86C")

	static let oneDark = CodeTheme(
		id: "one-dark", name: "One Dark", isDark: true,
		background: "#282C34", text: "#ABB2BF", lineNumber: "#636D83",
		keyword: "#C678DD", type: "#E5C07B", member: "#61AFEF", number: "#D19A66",
		string: "#98C379", comment: "#7F848E", attribute: "#E06C75")

	static let monokai = CodeTheme(
		id: "monokai", name: "Monokai", isDark: true,
		background: "#272822", text: "#F8F8F2", lineNumber: "#90908A",
		keyword: "#F92672", type: "#66D9EF", member: "#A6E22E", number: "#AE81FF",
		string: "#E6DB74", comment: "#88846F", attribute: "#FD971F")

	static let nord = CodeTheme(
		id: "nord", name: "Nord", isDark: true,
		background: "#2E3440", text: "#D8DEE9", lineNumber: "#4C566A",
		keyword: "#81A1C1", type: "#8FBCBB", member: "#88C0D0", number: "#B48EAD",
		string: "#A3BE8C", comment: "#616E88", attribute: "#D08770")

	static let solarizedDark = CodeTheme(
		id: "solarized-dark", name: "Solarized Dark", isDark: true,
		background: "#002B36", text: "#93A1A1", lineNumber: "#586E75",
		keyword: "#859900", type: "#B58900", member: "#268BD2", number: "#D33682",
		string: "#2AA198", comment: "#586E75", attribute: "#CB4B16")

	static let solarizedLight = CodeTheme(
		id: "solarized-light", name: "Solarized Light", isDark: false,
		background: "#FDF6E3", text: "#586E75", lineNumber: "#93A1A1",
		keyword: "#859900", type: "#B58900", member: "#268BD2", number: "#D33682",
		string: "#2AA198", comment: "#93A1A1", attribute: "#CB4B16")

	static let tokyoNight = CodeTheme(
		id: "tokyo-night", name: "Tokyo Night", isDark: true,
		background: "#1A1B26", text: "#C0CAF5", lineNumber: "#3B4261",
		keyword: "#BB9AF7", type: "#2AC3DE", member: "#7AA2F7", number: "#FF9E64",
		string: "#9ECE6A", comment: "#565F89", attribute: "#F7768E")

	static let catppuccinMocha = CodeTheme(
		id: "catppuccin-mocha", name: "Catppuccin Mocha", isDark: true,
		background: "#1E1E2E", text: "#CDD6F4", lineNumber: "#6C7086",
		keyword: "#CBA6F7", type: "#F9E2AF", member: "#89B4FA", number: "#FAB387",
		string: "#A6E3A1", comment: "#9399B2", attribute: "#F38BA8")

	static let all: [CodeTheme] = [
		xcodeDark, xcodeLight, githubDark, githubLight, gruvboxDark, gruvboxLight, x96f, darcula,
		dracula, oneDark, monokai, nord, solarizedDark, solarizedLight, tokyoNight, catppuccinMocha,
	]
}
