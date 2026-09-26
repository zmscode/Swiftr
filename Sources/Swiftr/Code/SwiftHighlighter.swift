import AppKit
import SwiftUI

/// Minimal Swift syntax coloring for the generated code. Later rules win where they overlap, so
/// strings and comments go last.
enum SwiftHighlighter {
	private enum Token { case type, member, number, keyword, attribute, string, comment }

	private static let rules: [(Token, NSRegularExpression)] = [
		(.type, #"\b[A-Z][A-Za-z0-9]*\b"#),
		(.member, #"\.[a-z][A-Za-z0-9]*"#),
		(.number, #"\b\d+(\.\d+)?\b"#),
		(.keyword, #"\b(import|struct|var|let|some|private|in|true|false|return)\b"#),
		(.attribute, #"@[A-Za-z]+|#Preview"#),
		(.string, #""(?:[^"\\]|\\.)*""#),
		(.comment, #"//.*"#),
	].compactMap { token, pattern in
		(try? NSRegularExpression(pattern: pattern)).map { (token, $0) }
	}

	static func highlight(_ code: String, theme: CodeTheme, fontSize: CGFloat) -> AttributedString {
		let regular = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
		let bold = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
		let text = NSMutableAttributedString(
			string: code,
			attributes: [
				.foregroundColor: theme.nsColor(theme.text), .font: regular,
			])
		let range = NSRange(code.startIndex..., in: code)
		for (token, regex) in rules {
			let hex: String
			switch token {
			case .type: hex = theme.type
			case .member: hex = theme.member
			case .number: hex = theme.number
			case .keyword: hex = theme.keyword
			case .attribute: hex = theme.attribute
			case .string: hex = theme.string
			case .comment: hex = theme.comment
			}
			let isBold = theme.boldKeywords && (token == .keyword || token == .attribute)
			for match in regex.matches(in: code, range: range) {
				text.addAttributes(
					[.foregroundColor: theme.nsColor(hex), .font: isBold ? bold : regular],
					range: match.range)
			}
		}
		return (try? AttributedString(text, including: \.appKit)) ?? AttributedString(code)
	}
}
