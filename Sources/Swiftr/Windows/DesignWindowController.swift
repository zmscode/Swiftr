import AppKit
import SwiftUI

/// A real window showing one design. Resizing or moving it writes back to the model; changing the
/// model resizes it. Title bar style and resizability are baked into the window's style mask, so
/// changing them rebuilds the window in place.
@MainActor
final class DesignWindowController: NSObject, NSWindowDelegate {
	let id: UUID
	private unowned let manager: WindowManager
	private(set) var window: NSWindow
	private var chrome: Chrome
	/// Set while we change the window ourselves, so the resulting delegate callbacks are ignored.
	private var isApplying = false

	private struct Chrome: Equatable {
		var titleBar: TitleBarStyle
		var resizable: Bool
		init(_ s: WindowSettings) {
			titleBar = s.titleBar
			resizable = s.resizable
		}
	}

	init(design: DesignWindow, index: Int, manager: WindowManager) {
		id = design.id
		self.manager = manager
		chrome = Chrome(design.settings)
		window = Self.makeWindow(design, model: manager.model)
		super.init()
		window.delegate = self

		if let topLeft = design.position {
			window.setFrameTopLeftPoint(topLeft)
		} else {
			// Cascade new windows from the middle of the screen, between the panels.
			let screen = NSScreen.main?.visibleFrame ?? .zero
			let offset = CGFloat(index % 8) * 28
			window.setFrameTopLeftPoint(
				NSPoint(
					x: screen.midX - window.frame.width / 2 + offset,
					y: screen.maxY - 80 - offset))
			manager.model.windowWasMoved(id, topLeft: topLeftPoint)
		}
	}

	private var topLeftPoint: CGPoint { CGPoint(x: window.frame.minX, y: window.frame.maxY) }

	private static func makeWindow(_ design: DesignWindow, model: DesignModel) -> NSWindow {
		let s = design.settings
		var mask: NSWindow.StyleMask
		switch s.titleBar {
		case .standard: mask = [.titled, .closable, .miniaturizable]
		case .hidden: mask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
		case .plain: mask = [.borderless]
		}
		if s.resizable { mask.insert(.resizable) }

		let window = DesignNSWindow(
			contentRect: NSRect(x: 0, y: 0, width: s.width, height: s.height),
			styleMask: mask, backing: .buffered, defer: false)
		window.title = s.title
		window.isReleasedWhenClosed = false
		window.isRestorable = false
		window.tabbingMode = .disallowed
		// Lets the drag-cleanup monitor see the pointer moving after a cancelled drag.
		window.acceptsMouseMovedEvents = true
		if s.titleBar == .hidden {
			window.titlebarAppearsTransparent = true
			window.titleVisibility = .hidden
		}
		if s.titleBar == .plain {
			window.isMovableByWindowBackground = true
			window.hasShadow = true
		}
		let host = NSHostingView(
			rootView: AnyView(DesignWindowContent(windowID: design.id).environment(model)))
		// The window's size comes from the model, not from the SwiftUI content.
		host.sizingOptions = []
		window.contentView = host
		return window
	}

	func apply(_ design: DesignWindow, previewing: Bool) {
		let s = design.settings
		if Chrome(s) != chrome { rebuild(design) }

		isApplying = true
		defer { isApplying = false }

		if window.title != s.title { window.title = s.title }

		let current = window.contentRect(forFrameRect: window.frame).size
		if !window.inLiveResize
			&& (abs(current.width - s.width) > 0.5 || abs(current.height - s.height) > 0.5)
		{
			// Resize keeping the top-left corner fixed, like a real window does.
			var frame = window.frameRect(
				forContentRect: NSRect(x: 0, y: 0, width: s.width, height: s.height))
			frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
			window.setFrame(frame, display: true, animate: false)
		}

		window.level = previewing && s.floating ? .floating : .normal
	}

	private func rebuild(_ design: DesignWindow) {
		let topLeft = topLeftPoint
		let wasKey = window.isKeyWindow
		window.delegate = nil
		window.orderOut(nil)

		chrome = Chrome(design.settings)
		window = Self.makeWindow(design, model: manager.model)
		window.delegate = self
		window.setFrameTopLeftPoint(topLeft)
		if wasKey { window.makeKeyAndOrderFront(nil) } else { window.orderFront(nil) }
	}

	func close() {
		window.delegate = nil
		window.orderOut(nil)
	}

	// MARK: NSWindowDelegate

	func windowShouldClose(_ sender: NSWindow) -> Bool {
		// Closing only hides the window; it stays in the project and in the layers list.
		manager.model.hideWindow(id)
		return false
	}

	func windowDidResize(_ notification: Notification) {
		guard !isApplying else { return }
		manager.model.windowWasResized(id, to: window.contentRect(forFrameRect: window.frame).size)
	}

	func windowDidMove(_ notification: Notification) {
		guard !isApplying else { return }
		manager.model.windowWasMoved(id, topLeft: topLeftPoint)
	}

	func windowDidBecomeKey(_ notification: Notification) {
		manager.model.activeWindowID = id
	}
}

/// Borderless windows can't normally become key; design windows always need to.
final class DesignNSWindow: NSWindow {
	override var canBecomeKey: Bool { true }
	override var canBecomeMain: Bool { true }
}
