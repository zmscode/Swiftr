import AppKit
import SwiftUI

/// Owns every window in the app: the floating tool panels, one real window per design window,
/// and the code window. Design windows are created, updated and closed to match the model.
@MainActor
final class WindowManager: NSObject {
	let model: DesignModel
	private var libraryPanel: NSPanel!
	private var inspectorPanel: NSPanel!
	private var conditionsPanel: NSPanel!
	private var codeWindow: NSWindow?
	private var designWindows: [UUID: DesignWindowController] = [:]
	private var keyMonitor: Any?
	private var dragCleanupMonitor: Any?

	init(model: DesignModel) {
		self.model = model
		super.init()
		model.windowManager = self

		// Bumping the ".3" names starts everyone on the current default layout once; after that,
		// where you put the panels is remembered again.
		libraryPanel = makePanel(
			title: "Library", autosave: "LibraryPanel.3", frame: Self.defaultFrame(.library),
			content: LibraryPanel()
		)
		inspectorPanel = makePanel(
			title: "Inspector", autosave: "InspectorPanel.3", frame: Self.defaultFrame(.inspector),
			content: InspectorView()
		)
		conditionsPanel = makePanel(
			title: "Conditions", autosave: "ConditionsPanel.1", frame: Self.defaultFrame(.conditions),
			keyOnlyIfNeeded: false, content: ConditionsPanel()
		)
		conditionsPanel.minSize = NSSize(width: 480, height: 260)
		NotificationCenter.default.addObserver(
			forName: NSWindow.willCloseNotification, object: conditionsPanel, queue: .main
		) { _ in UserDefaults.standard.set(false, forKey: WindowManager.conditionsOpenKey) }

		sync()
		observeModel()
		installKeyMonitor()
		installDragCleanup()
		showPanels()
		if UserDefaults.standard.bool(forKey: Self.conditionsOpenKey) { conditionsPanel.orderFront(nil) }
		if let first = model.project.windows.first { focus(first.id) }
	}

	// MARK: Panels

	private func makePanel(
		title: String, autosave: String, frame: NSRect, keyOnlyIfNeeded: Bool = true, content: some View
	) -> NSPanel {
		let panel = NSPanel(
			contentRect: frame,
			styleMask: [.titled, .closable, .resizable, .utilityWindow],
			backing: .buffered, defer: false)
		panel.title = title
		panel.isFloatingPanel = true
		panel.hidesOnDeactivate = true
		// Stay out of the way: only take keyboard focus when a text field is clicked. (The
		// Conditions panel takes it on any click, so Delete and arrows reach the node editor.)
		panel.becomesKeyOnlyIfNeeded = keyOnlyIfNeeded
		panel.isReleasedWhenClosed = false
		panel.isRestorable = false
		panel.minSize = NSSize(width: 240, height: 300)
		let host = NSHostingView(
			rootView: AnyView(content.modifier(ThemedPanel()).environment(model)))
		host.sizingOptions = []
		panel.contentView = host
		panel.setFrame(frame, display: false)
		panel.setFrameAutosaveName(autosave)
		return panel
	}

	private enum PanelSide { case library, inspector, conditions }

	/// Panels default to hanging from just below the top of the screen, 85% of the usable height
	/// tall, a little in from the left (Library) and right (Inspector) edges.
	private static func defaultFrame(_ side: PanelSide) -> NSRect {
		let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
		let inset: CGFloat = 16
		let topGap: CGFloat = 12
		let height = (screen.height * 0.85).rounded()
		let y = screen.maxY - topGap - height
		switch side {
		case .library: return NSRect(x: screen.minX + inset, y: y, width: 270, height: height)
		case .inspector: return NSRect(x: screen.maxX - inset - 310, y: y, width: 310, height: height)
		case .conditions:
			// Along the bottom, between the Library and the Inspector.
			let left = screen.minX + inset + 270 + inset
			let right = screen.maxX - inset - 310 - inset
			let h = min(420, (screen.height * 0.4).rounded())
			return NSRect(x: left, y: screen.minY + inset, width: max(480, right - left), height: h)
		}
	}

	/// Window → Reset Panel Layout.
	func resetPanelLayout() {
		libraryPanel.setFrame(Self.defaultFrame(.library), display: true, animate: true)
		inspectorPanel.setFrame(Self.defaultFrame(.inspector), display: true, animate: true)
		conditionsPanel.setFrame(Self.defaultFrame(.conditions), display: true, animate: true)
		showPanels()
	}

	func showPanels() {
		libraryPanel.orderFront(nil)
		inspectorPanel.orderFront(nil)
	}

	func showLibrary() { libraryPanel.orderFront(nil) }
	func showInspector() { inspectorPanel.orderFront(nil) }

	/// Opens the Conditions panel, on a particular window's conditions if given.
	func showConditions(for windowID: UUID? = nil) {
		if let windowID { model.conditionsWindowID = windowID }
		conditionsPanel.makeKeyAndOrderFront(nil)
		UserDefaults.standard.set(true, forKey: Self.conditionsOpenKey)
	}

	/// Whether the Conditions panel was open, so it reopens at launch.
	nonisolated private static let conditionsOpenKey = "conditionsPanelOpen"

	func showCode() {
		if codeWindow == nil {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
				styleMask: [.titled, .closable, .resizable, .miniaturizable],
				backing: .buffered, defer: false)
			window.title = "Generated Code"
			window.isReleasedWhenClosed = false
			window.isRestorable = false
			window.contentView = NSHostingView(rootView: CodeView().environment(model))
			window.center()
			window.setFrameAutosaveName("CodeWindow")
			codeWindow = window
		}
		codeWindow?.makeKeyAndOrderFront(nil)
	}

	// MARK: Design windows

	/// Brings a design window to the front, showing it if it was hidden.
	func focus(_ id: UUID, makeKey: Bool = true) {
		sync()
		guard let window = designWindows[id]?.window else { return }
		if makeKey { window.makeKeyAndOrderFront(nil) } else { window.orderFront(nil) }
	}

	/// Makes the set of open windows, and each window's size, title and style, match the model.
	private func sync() {
		updateTitles()
		let visible = model.project.windows.filter { !model.hiddenWindows.contains($0.id) }
		let visibleIDs = Set(visible.map(\.id))

		for (id, controller) in designWindows where !visibleIDs.contains(id) {
			controller.close()
			designWindows[id] = nil
		}

		for (index, design) in visible.enumerated() {
			if let controller = designWindows[design.id] {
				controller.apply(design, previewing: model.isPreviewing)
			} else {
				let controller = DesignWindowController(design: design, index: index, manager: self)
				designWindows[design.id] = controller
				controller.apply(design, previewing: model.isPreviewing)
				controller.window.orderFront(nil)
			}
		}
	}

	/// Re-syncs whenever anything the windows depend on changes.
	private func observeModel() {
		withObservationTracking {
			_ = model.project
			_ = model.hiddenWindows
			_ = model.isPreviewing
			_ = model.fileURL
			_ = model.savedProject
		} onChange: { [weak self] in
			// Changes arrive on the main thread (the model is only mutated from UI code); defer the
			// sync until the mutation has finished.
			Task { @MainActor in
				self?.sync()
				self?.observeModel()
			}
		}
	}

	/// The Library panel's title names the project and marks unsaved changes; its close button
	/// shows the edited dot, and the title's proxy icon is the project file.
	private func updateTitles() {
		let edited = model.isDirty
		libraryPanel.title = "\(model.projectName)\(edited ? " — Edited" : "")"
		libraryPanel.representedURL = model.fileURL
		libraryPanel.isDocumentEdited = edited
		inspectorPanel.isDocumentEdited = edited
	}

	// MARK: Keys

	/// Bare Delete and Escape act on the selection in any of the builder's windows, unless a text
	/// field is being edited or the designs are being previewed.
	/// A drag that ends without a drop (cancelled, or released somewhere that doesn't accept it)
	/// doesn't always tell the window it left, which would leave the drop marker showing. Clear it
	/// on the next mouse event once no button is held.
	private func installDragCleanup() {
		dragCleanupMonitor = NSEvent.addLocalMonitorForEvents(
			matching: [.mouseMoved, .leftMouseUp, .leftMouseDown, .mouseEntered, .mouseExited]
		) { [weak self] event in
			if let model = self?.model, NSEvent.pressedMouseButtons & 1 == 0,
				model.dropIndicator != nil || model.dropPreview != nil || model.layerDropTarget != nil
			{
				model.dropIndicator = nil
				model.layerDropTarget = nil
				model.endDropPreview()
				model.draggingPayload = nil
			}
			return event
		}
	}

	private func installKeyMonitor() {
		keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard let self else { return event }
			return self.handleKeyDown(event)
		}
	}

	private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
		guard !model.isPreviewing, let window = event.window, isEditorWindow(window),
			!TextFocus.isEditing(in: window)
		else { return event }
		let mods = event.modifierFlags.intersection([.command, .control, .option])
		guard mods.isEmpty else { return event }

		switch event.keyCode {
		case KeyCode.delete, KeyCode.forwardDelete:
			guard model.canEditSelection else { return event }
			model.deleteSelection()
			return nil
		case KeyCode.escape:
			if model.inPlaceEdit != nil {
				model.inPlaceEdit = nil
				return nil
			}
			guard model.selection != nil else { return event }
			model.selectParent()
			return nil
		default:
			return event
		}
	}

	private func isEditorWindow(_ window: NSWindow) -> Bool {
		window === libraryPanel || window === inspectorPanel
			|| designWindows.values.contains { $0.window === window }
	}
}
