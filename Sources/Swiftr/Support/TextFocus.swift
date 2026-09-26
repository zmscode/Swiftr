import AppKit
import SwiftUI

/// Helpers for routing standard edit commands to a focused text field instead of the design.
enum TextFocus {
	static func isEditing(in window: NSWindow? = NSApp.keyWindow) -> Bool {
		window?.firstResponder is NSText
	}

	/// Sends `action` to the focused text field if there is one; otherwise runs `fallback`.
	static func forward(_ action: String, else fallback: () -> Void) {
		if isEditing() {
			NSApp.sendAction(Selector(action), to: nil, from: nil)
		} else {
			fallback()
		}
	}
}

enum KeyCode {
	static let delete: UInt16 = 51
	static let forwardDelete: UInt16 = 117
	static let escape: UInt16 = 53
}
