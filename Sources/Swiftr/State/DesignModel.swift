import AppKit
import SwiftUI

@Observable @MainActor
final class DesignModel {
	var project = Project()
	/// The primary selection, shown in the inspector.
	var selection: UUID? {
		didSet {
			if !isExtendingSelection { selectedIDs = selection.map { [$0] } ?? [] }
		}
	}
	/// Everything selected (Shift-click adds and removes). Always includes `selection`.
	var selectedIDs: Set<UUID> = []
	@ObservationIgnored private var isExtendingSelection = false
	/// The drag-selection box being drawn in a design window, if any.
	var marquee: Marquee?
	/// Each design window's component frames (in window coordinates), reported by its content view.
	@ObservationIgnored var nodeFrames: [UUID: [UUID: CGRect]] = [:]
	@ObservationIgnored private var marqueeBase: Set<UUID> = []
	/// Where a drag over a design window would drop, for drawing the insertion marker.
	var dropIndicator: DropTarget?
	/// The payload of the drag in progress ("new:<kind>" or "move:<uuid>"), recorded when it starts
	/// so drop targets can be worked out while hovering, before the payload itself can be read.
	@ObservationIgnored var draggingPayload: String?
	var hovered: UUID?
	/// Containers folded shut in the layers panel.
	var collapsed: Set<UUID> = []

	/// Design windows the user has closed. They stay in the project and can be reopened.
	var hiddenWindows: Set<UUID> = []
	/// The design window most recently brought to front; new components go here when nothing is selected.
	var activeWindowID: UUID?
	/// In Preview mode the design windows behave like the finished app and can't be edited.
	var isPreviewing = false {
		didSet {
			inPlaceEdit = nil
			// Each preview starts from the controls' initial values.
			liveValues = [:]
		}
	}
	/// The design window whose conditions the Conditions panel shows (nil follows the selection).
	var conditionsWindowID: UUID?
	/// Control values while previewing, so conditions can react to them.
	var liveValues: [UUID: ConditionValue] = [:]
	/// The component being edited directly in its window after a double-click: inline text,
	/// the symbol browser, or shape handles, depending on its kind.
	var inPlaceEdit: UUID?
	var fileURL: URL?

	@ObservationIgnored weak var windowManager: WindowManager?

	var selectedNode: Node? { selection.flatMap { project.find($0) } }
	var canEditSelection: Bool { !editableSelection.isEmpty }

	/// Selected components in tree order, leaving out window roots and anything inside another
	/// selected component (it moves or is deleted along with its parent).
	var editableSelection: [UUID] {
		var result: [UUID] = []
		func visit(_ node: Node, isRoot: Bool, insideSelected: Bool) {
			let isSelected = selectedIDs.contains(node.id) && !isRoot
			if isSelected && !insideSelected { result.append(node.id) }
			for child in node.children {
				visit(child, isRoot: false, insideSelected: insideSelected || isSelected)
			}
		}
		for window in project.windows { visit(window.root, isRoot: true, insideSelected: false) }
		return result
	}

	/// The window containing the selection.
	var selectedWindow: DesignWindow? {
		selection.flatMap { project.windowIndex(containing: $0) }.map { project.windows[$0] }
	}

	// MARK: Undo / redo

	private(set) var undoStack: [Project] = []
	private(set) var redoStack: [Project] = []
	@ObservationIgnored private var lastEditKey: AnyHashable?
	@ObservationIgnored private var lastEditTime = Date.distantPast

	var canUndo: Bool { !undoStack.isEmpty }
	var canRedo: Bool { !redoStack.isEmpty }

	/// Records the current project before a change. Repeated edits with the same key in quick
	/// succession (typing, dragging a slider, resizing a window) collapse into one undo step.
	func snapshot(coalescing key: AnyHashable? = nil) {
		let now = Date()
		defer {
			lastEditKey = key
			lastEditTime = now
		}
		if let key, key == lastEditKey, now.timeIntervalSince(lastEditTime) < 1.5 { return }
		undoStack.append(project)
		if undoStack.count > 200 { undoStack.removeFirst() }
		redoStack.removeAll()
	}

	func undo() {
		guard let previous = undoStack.popLast() else { return }
		redoStack.append(project)
		project = previous
		afterHistoryJump()
	}

	func redo() {
		guard let next = redoStack.popLast() else { return }
		undoStack.append(project)
		project = next
		afterHistoryJump()
	}

	private func afterHistoryJump() {
		lastEditKey = nil
		if let sel = selection, project.find(sel) == nil { selection = nil }
	}

	// MARK: Bindings for the inspector

	struct EditKey: Hashable {
		let id: UUID?
		let path: AnyKeyPath
	}

	func propBinding<T: Equatable>(_ id: UUID, _ path: WritableKeyPath<Props, T>) -> Binding<T> {
		Binding(
			get: { self.project.find(id)?.props[keyPath: path] ?? Props()[keyPath: path] },
			set: { newValue in
				self.updateProps(id, key: path) { $0[keyPath: path] = newValue }
			}
		)
	}

	/// Applies a change to a node's props as one (coalescable) undo step. No-op changes aren't recorded.
	func updateProps(_ id: UUID, key: AnyKeyPath, _ change: (inout Props) -> Void) {
		guard let node = project.find(id) else { return }
		var props = node.props
		change(&props)
		guard props != node.props else { return }
		snapshot(coalescing: EditKey(id: id, path: key))
		project.modify(id) { $0.props = props }
	}

	func windowBinding<T: Equatable>(_ windowID: UUID, _ path: WritableKeyPath<WindowSettings, T>)
		-> Binding<T>
	{
		Binding(
			get: {
				self.project.window(windowID)?.settings[keyPath: path]
					?? WindowSettings()[keyPath: path]
			},
			set: { newValue in
				guard let i = self.project.windowIndex(windowID),
					self.project.windows[i].settings[keyPath: path] != newValue
				else { return }
				self.snapshot(coalescing: EditKey(id: windowID, path: path))
				self.project.windows[i].settings[keyPath: path] = newValue
			}
		)
	}

	func viewNameBinding(_ windowID: UUID) -> Binding<String> {
		Binding(
			get: { self.project.window(windowID)?.viewName ?? "" },
			set: { newValue in
				guard let i = self.project.windowIndex(windowID) else { return }
				let name = self.project.uniqueViewName(newValue, excluding: windowID)
				guard name != self.project.windows[i].viewName else { return }
				self.snapshot(coalescing: EditKey(id: windowID, path: \DesignWindow.viewName))
				self.project.windows[i].viewName = name
			}
		)
	}

	var appNameBinding: Binding<String> {
		Binding(
			get: { self.project.appName },
			set: { newValue in
				let name = Identifier.typeName(newValue, fallback: "MyApp")
				guard name != self.project.appName else { return }
				self.snapshot(coalescing: EditKey(id: nil, path: \Project.appName))
				self.project.appName = name
			}
		)
	}

	// MARK: Selection

	/// Selecting in a design window also ends any text editing in the inspector, so Delete and
	/// the other shortcuts act on the component instead of the text field.
	func select(_ id: UUID?, extending: Bool = false) {
		NSApp.keyWindow?.makeFirstResponder(nil)
		if id != inPlaceEdit { inPlaceEdit = nil }
		// Window roots can't be part of a multiple selection.
		guard extending, let id, !project.isRoot(id) else {
			selection = id
			return
		}
		var ids = selectedIDs.filter { !project.isRoot($0) }
		if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
		setSelection(ids, primary: ids.contains(id) ? id : nil)
	}

	// MARK: Drag selection

	struct Marquee: Equatable {
		let windowID: UUID
		let rect: CGRect
	}

	/// Drag-selects in a window: selects the components fully inside the box, live. With `extending`
	/// (Shift held when the drag starts), they're added to what was already selected.
	func updateMarquee(in windowID: UUID, from start: CGPoint, to end: CGPoint, extending: Bool) {
		if marquee == nil {
			NSApp.keyWindow?.makeFirstResponder(nil)
			inPlaceEdit = nil
			marqueeBase = extending ? selectedIDs.filter { !project.isRoot($0) } : []
		}
		let rect = CGRect(
			x: min(start.x, end.x), y: min(start.y, end.y),
			width: abs(end.x - start.x), height: abs(end.y - start.y))
		marquee = Marquee(windowID: windowID, rect: rect)

		guard let window = project.window(windowID) else { return }
		let frames = nodeFrames[windowID] ?? [:]
		var hits: [UUID] = []
		// The topmost components inside the box; a container wholly inside counts as one.
		func visit(_ node: Node) {
			if !project.fillsWindow(node.id), let frame = frames[node.id], rect.contains(frame) {
				hits.append(node.id)
				return
			}
			node.children.forEach(visit)
		}
		visit(window.root)
		let ids = marqueeBase.union(hits)
		setSelection(ids, primary: hits.last)
		if ids.isEmpty { selection = nil }
	}

	func endMarquee() {
		marquee = nil
		marqueeBase = []
	}

	/// Replaces the whole selection, e.g. from the layers list.
	func setSelection(_ ids: Set<UUID>, primary: UUID? = nil) {
		isExtendingSelection = true
		defer { isExtendingSelection = false }
		selectedIDs = ids
		if let primary, ids.contains(primary) {
			selection = primary
		} else if let current = selection, ids.contains(current) {
			// Keep the inspector on the same component.
		} else {
			selection = editableSelection.last ?? ids.first
		}
	}

	/// Double-click in a design window.
	func beginInPlaceEdit(_ id: UUID) {
		guard let node = project.find(id), Self.supportsInPlaceEdit(node.kind) else { return }
		select(id)
		inPlaceEdit = id
	}

	static func supportsInPlaceEdit(_ kind: ComponentKind) -> Bool {
		kind.isShape || kind == .photo || kind == .divider || kind.usesSymbol
			|| [.text, .button, .link, .toggle].contains(kind)
	}

	func selectParent() {
		guard let sel = selection else { return }
		selection = project.parent(of: sel)?.id
	}

	// MARK: Windows

	func addWindow() {
		snapshot()
		let n = project.windows.count + 1
		var window = DesignWindow(viewName: project.uniqueViewName("Window\(n)View"))
		window.settings.title = "Window \(n)"
		window.settings.width = 360
		window.settings.height = 280
		project.windows.append(window)
		selection = window.root.id
		activeWindowID = window.id
	}

	func duplicateWindow(_ id: UUID) {
		guard let original = project.window(id) else { return }
		snapshot()
		var copy = original
		copy.id = UUID()
		copy.root = original.root.withNewIDs()
		copy.viewName = project.uniqueViewName(original.viewName)
		copy.settings.title += " Copy"
		copy.position = original.position.map { CGPoint(x: $0.x + 30, y: $0.y - 30) }
		project.windows.append(copy)
		selection = copy.root.id
	}

	func deleteWindow(_ id: UUID) {
		guard let i = project.windowIndex(id) else { return }
		snapshot()
		if let sel = selection, project.windows[i].root.find(sel) != nil { selection = nil }
		project.windows.remove(at: i)
		// Buttons that opened this window no longer do anything.
		for w in project.windows.indices {
			project.windows[w].root.forEach { node in
				if node.props.action == .openWindow(id) { node.props.action = nil }
			}
		}
	}

	func showWindow(_ id: UUID) {
		hiddenWindows.remove(id)
		windowManager?.focus(id)
	}

	func hideWindow(_ id: UUID) {
		hiddenWindows.insert(id)
	}

	/// From the real window being resized by the user.
	func windowWasResized(_ id: UUID, to size: CGSize) {
		guard let i = project.windowIndex(id) else { return }
		let w = size.width.rounded()
		let h = size.height.rounded()
		let s = project.windows[i].settings
		guard s.width != w || s.height != h else { return }
		snapshot(coalescing: EditKey(id: id, path: \WindowSettings.width))
		project.windows[i].settings.width = w
		project.windows[i].settings.height = h
	}

	/// From the real window being moved. Positions aren't undoable design changes.
	func windowWasMoved(_ id: UUID, topLeft: CGPoint) {
		guard let i = project.windowIndex(id), project.windows[i].position != topLeft else {
			return
		}
		project.windows[i].position = topLeft
	}

	/// Runs a button's action in Preview mode, mirroring what the generated code does.
	func perform(_ action: ButtonAction?, from windowID: UUID) {
		switch action {
		case .openWindow(let id): showWindow(id)
		case .closeWindow: hideWindow(windowID)
		case nil: break
		}
	}

	// MARK: Editing

	/// Drag payloads are plain strings: "new:<kind>" from the palette, "move:<uuid>" from a window or the layers list.
	@discardableResult
	func handleDrop(_ payload: String?, _ target: DropTarget) -> Bool {
		guard !isPreviewing, let (node, movingID) = dropped(payload) else { return false }
		var next = project
		// A new component placed by a preview must not be reused by the next drop (same id).
		endDropPreview()
		guard next.drop(node, movingID: movingID, at: target) else { return false }
		snapshot()
		project = next
		// A component moved to another window takes its place in that window's state instead.
		project.pruneConditions()
		if let parentID = next.parentID(for: target) { collapsed.remove(parentID) }
		selection = node.id
		return true
	}

	/// The component a payload places, and the id it's moving from (nil for a new one).
	private func dropped(_ payload: String?) -> (Node, UUID?)? {
		guard let payload else { return nil }
		if payload.hasPrefix("new:"), let kind = ComponentKind(rawValue: String(payload.dropFirst(4))) {
			// Reuse the same new component while previewing, so the preview and drop agree.
			if let cached = previewNode, cached.payload == payload { return (cached.node, nil) }
			return (Node.make(kind), nil)
		}
		if payload.hasPrefix("move:"), let id = UUID(uuidString: String(payload.dropFirst(5))),
			!project.isRoot(id), let existing = project.find(id)
		{
			return (existing, id)
		}
		return nil
	}

	func canDrop(_ node: Node, movingID: UUID?, at target: DropTarget) -> Bool {
		project.canDrop(node, movingID: movingID, at: target)
	}

	private func place(_ node: Node, at target: DropTarget) {
		project.drop(node, movingID: nil, at: target)
		if let parentID = project.parentID(for: target) { collapsed.remove(parentID) }
	}

	// MARK: Drop preview

	/// While dragging over the layers list: the project as it would be after the drop, which the
	/// design windows show instead, and the component being placed (drawn faded).
	struct DropPreview {
		let project: Project
		let ghostID: UUID
		let target: DropTarget
	}

	var dropPreview: DropPreview?
	/// Where a drag over the layers list would drop, for its insertion line.
	var layerDropTarget: DropTarget?
	@ObservationIgnored private var previewNode: (payload: String, node: Node)?

	/// What the design windows draw: the drop preview while there is one, otherwise the project.
	var displayedProject: Project { dropPreview?.project ?? project }

	/// Shows (or clears, for nil) what dropping the current drag at `target` would do.
	func previewDrop(at target: DropTarget?) {
		guard let target, let payload = draggingPayload, !isPreviewing else {
			if dropPreview != nil { dropPreview = nil }
			return
		}
		if dropPreview?.target == target { return }
		if payload.hasPrefix("new:"), previewNode?.payload != payload,
			let kind = ComponentKind(rawValue: String(payload.dropFirst(4)))
		{
			previewNode = (payload, Node.make(kind))
		}
		guard let (node, movingID) = dropped(payload) else { return }
		var next = project
		if next.drop(node, movingID: movingID, at: target) {
			dropPreview = DropPreview(project: next, ghostID: node.id, target: target)
		} else {
			dropPreview = nil
		}
	}

	func endDropPreview() {
		dropPreview = nil
		previewNode = nil
	}

	/// Double-click in the palette: add into the selected container, or next to the selected item,
	/// or into the active window.
	func add(_ kind: ComponentKind) {
		insert([Node.make(kind)])
	}

	private func insert(_ nodes: [Node], recordingUndo: Bool = true) {
		guard !nodes.isEmpty else { return }
		if recordingUndo { snapshot() }
		for node in nodes.reversed() {
			if let sel = selection, let selected = project.find(sel),
				selected.kind.isContainer, selected.kind.accepts(node.kind)
			{
				place(node, at: .at(sel, index: selected.children.count))
			} else if let sel = selection, project.find(sel) != nil, !project.isRoot(sel),
				project.parent(of: sel)?.kind.accepts(node.kind) ?? false
			{
				project.insert(node, beside: sel, after: true)
			} else {
				if project.windows.isEmpty { project.windows.append(DesignWindow()) }
				let target =
					selectedWindow.flatMap { project.windowIndex($0.id) }
					?? activeWindowID.flatMap { project.windowIndex($0) } ?? 0
				place(node, at: .into(project.windows[target].root.id))
				hiddenWindows.remove(project.windows[target].id)
			}
		}
		setSelection(Set(nodes.map(\.id)), primary: nodes.last?.id)
	}

	func deleteSelection() {
		let ids = editableSelection
		guard let first = ids.first else { return }
		snapshot()
		let parentID = project.parent(of: first)?.id
		for id in ids { project.remove(id) }
		project.pruneConditions()
		selection = parentID
	}

	func duplicateSelection() {
		if let id = selection, let window = project.windows.first(where: { $0.root.id == id }) {
			duplicateWindow(window.id)
			return
		}
		let ids = editableSelection
		guard !ids.isEmpty else { return }
		snapshot()
		var copies: [UUID] = []
		for id in ids {
			guard let node = project.find(id) else { continue }
			let copy = node.withNewIDs()
			project.insert(copy, beside: id, after: true)
			copies.append(copy.id)
		}
		setSelection(Set(copies), primary: copies.last)
	}

	/// Names a component in the layers list. An empty name goes back to the automatic one.
	func renameNode(_ id: UUID, to name: String) {
		let trimmed = name.trimmingCharacters(in: .whitespaces)
		let new: String? = trimmed.isEmpty ? nil : trimmed
		guard let node = project.find(id), node.name != new else { return }
		snapshot(coalescing: EditKey(id: id, path: \Node.name))
		project.modify(id) { $0.name = new }
	}

	/// Switches a stack between V, H and Z, keeping its children and style.
	func setKind(_ id: UUID, to kind: ComponentKind) {
		guard let node = project.find(id), node.kind != kind else { return }
		snapshot()
		project.modify(id) { $0.kind = kind }
	}

	// MARK: Navigation

	/// The image's own pixel size (in points), for "Original Size" and keeping proportions.
	func naturalSize(ofImageIn nodeID: UUID) -> CGSize? {
		guard let size = nsImage(project.find(nodeID)?.props.imageID)?.size, size.width > 0,
			size.height > 0
		else { return nil }
		return size
	}

	func resetImageSize(_ nodeID: UUID) {
		guard let size = naturalSize(ofImageIn: nodeID) else { return }
		updateProps(nodeID, key: \Props.width) { p in
			p.width = size.width.rounded()
			p.height = size.height.rounded()
			p.fillWidth = false
			p.fillHeight = false
		}
	}

	func addTab(to tabViewID: UUID) {
		guard let tabView = project.find(tabViewID) else { return }
		snapshot()
		let tab = Node.tab("Tab \(tabView.children.count + 1)", "square")
		project.modify(tabViewID) { $0.children.append(tab) }
		selection = tab.id
	}

	/// Two columns (sidebar, detail) or three (sidebar, content, detail).
	func setColumnCount(_ splitViewID: UUID, to count: Int) {
		guard let split = project.find(splitViewID), split.children.count != count else { return }
		snapshot()
		project.modify(splitViewID) { node in
			if count == 3, node.children.count == 2 {
				node.children.insert(Node.pane("Content"), at: 1)
			} else if count == 2, node.children.count >= 3 {
				node.children.remove(at: 1)
			}
		}
	}

	// MARK: Images

	@ObservationIgnored private var imageCache: [UUID: NSImage] = [:]

	/// The decoded image for a project image, cached.
	func nsImage(_ id: UUID?) -> NSImage? {
		guard let asset = project.image(id) else { return nil }
		if let cached = imageCache[asset.id] { return cached }
		let image = NSImage(data: asset.data)
		imageCache[asset.id] = image
		return image
	}

	/// Adds an image file to the project (no undo step of its own). Nil if it isn't an image.
	private func addImageAsset(from url: URL) -> ImageAsset? {
		guard let data = try? Data(contentsOf: url), NSImage(data: data) != nil else { return nil }
		let name = project.uniqueImageName(url.deletingPathExtension().lastPathComponent)
		let asset = ImageAsset(
			name: name, data: data, fileExtension: url.pathExtension.lowercased())
		project.images.append(asset)
		return asset
	}

	/// A new Image component showing an image file, sized to the image's shape.
	func insertImage(from url: URL, at target: DropTarget? = nil) {
		guard !isPreviewing else { return }
		snapshot()
		guard let asset = addImageAsset(from: url) else {
			undoStack.removeLast()
			NSSound.beep()
			return
		}
		var node = Node.make(.photo)
		node.props.imageID = asset.id
		if let size = nsImage(asset.id)?.size, size.width > 0, size.height > 0 {
			let width = min(size.width, 240)
			node.props.width = width.rounded()
			node.props.height = (width * size.height / size.width).rounded()
			node.props.contentMode = .fit
		}
		if let target, canDrop(node, movingID: nil, at: target) {
			place(node, at: target)
			selection = node.id
		} else {
			insert([node], recordingUndo: false)
		}
	}

	/// "Choose File…" in the inspector: pick an image file for an Image component.
	func chooseImage(for nodeID: UUID) {
		guard let url = FilePanels.openURL(types: [.image]) else { return }
		snapshot()
		guard let asset = addImageAsset(from: url) else {
			undoStack.removeLast()
			NSSound.beep()
			return
		}
		project.modify(nodeID) { $0.props.imageID = asset.id }
	}

	func renameImage(_ id: UUID, to proposed: String) {
		guard let i = project.images.firstIndex(where: { $0.id == id }) else { return }
		let name = project.uniqueImageName(proposed, excluding: id)
		guard name != project.images[i].name else { return }
		snapshot(coalescing: EditKey(id: id, path: \ImageAsset.name))
		project.images[i].name = name
	}

	/// Removes an image from the project; Image components that showed it become placeholders.
	func deleteImage(_ id: UUID) {
		guard let i = project.images.firstIndex(where: { $0.id == id }) else { return }
		snapshot()
		project.images.remove(at: i)
		for w in project.windows.indices {
			project.windows[w].root.forEach { if $0.props.imageID == id { $0.props.imageID = nil } }
		}
	}

	/// Writes each project image as an image set (`name.imageset`) into a chosen folder, normally
	/// the app's Assets.xcassets, so the generated `Image("name")` calls find them.
	func exportImages() {
		guard !project.images.isEmpty else { return }
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.prompt = "Export"
		panel.message = "Choose your app’s asset catalog (Assets.xcassets), or any folder."
		guard panel.runModal() == .OK, let folder = panel.url else { return }
		do {
			for asset in project.images {
				let set = folder.appendingPathComponent("\(asset.name).imageset", isDirectory: true)
				try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
				let file = "\(asset.name).\(asset.fileExtension)"
				try asset.data.write(to: set.appendingPathComponent(file), options: .atomic)
				let contents = """
					{
					  "images" : [ { "filename" : "\(file)", "idiom" : "universal" } ],
					  "info" : { "author" : "xcode", "version" : 1 }
					}
					"""
				try Data(contents.utf8).write(
					to: set.appendingPathComponent("Contents.json"), options: .atomic)
			}
			NSWorkspace.shared.activateFileViewerSelecting([folder])
		} catch {
			NSAlert(error: error).runModal()
		}
	}

	// MARK: Clipboard

	@ObservationIgnored private var clipboard: [Node] = []
	var canPaste: Bool { !clipboard.isEmpty }

	func copySelection() {
		let nodes = editableSelection.compactMap { project.find($0) }
		if !nodes.isEmpty { clipboard = nodes }
	}

	func cutSelection() {
		copySelection()
		deleteSelection()
	}

	func paste() {
		insert(clipboard.map { $0.withNewIDs() })
	}

	// MARK: Arrange

	/// Moves the selection earlier (-1) or later (+1) among its siblings.
	func moveSelection(by offset: Int) {
		guard canEditSelection, let id = selection, let parent = project.parent(of: id),
			let i = parent.children.firstIndex(where: { $0.id == id })
		else { return }
		let j = i + offset
		guard parent.children.indices.contains(j) else { return }
		snapshot()
		project.modify(parent.id) { $0.children.swapAt(i, j) }
	}

	/// Whether every selected component can go inside a new `kind` container.
	func canWrapSelection(in kind: ComponentKind) -> Bool {
		let ids = editableSelection
		return !ids.isEmpty
			&& ids.allSatisfy { project.find($0).map { kind.accepts($0.kind) } ?? false }
	}

	/// Puts every selected component into one new container, placed where the first one was.
	func wrapSelection(in kind: ComponentKind) {
		guard canWrapSelection(in: kind) else { return }
		let ids = editableSelection
		let nodes = ids.compactMap { project.find($0) }
		snapshot()
		var container = Node.make(kind)
		container.children = nodes
		// Remove the others first, so the first one's spot is still where it was.
		for id in ids.dropFirst() { project.remove(id) }
		project.modify(ids[0]) { $0 = container }
		selection = container.id
	}

	/// Replaces the selected container with its children.
	func unwrapSelection() {
		guard let id = selection, !project.isRoot(id), let node = project.find(id),
			node.kind.isContainer,
			let parent = project.parent(of: id)
		else { return }
		snapshot()
		project.modify(parent.id) { p in
			if let i = p.children.firstIndex(where: { $0.id == id }) {
				p.children.replaceSubrange(i...i, with: node.children)
			}
		}
		setSelection(Set(node.children.map(\.id)), primary: node.children.first?.id ?? parent.id)
	}

	var canUnwrap: Bool {
		selection.map { !project.isRoot($0) } == true && selectedNode?.kind.isContainer == true
	}

	// MARK: Files

	/// The project as last saved or opened, to tell whether there are unsaved changes.
	private(set) var savedProject = Project()
	/// Recently opened or saved projects, newest first.
	private(set) var recentProjects: [URL] = RecentProjects.load()

	/// Unsaved changes. Moving design windows around doesn't count.
	var isDirty: Bool { project.ignoringPositions != savedProject.ignoringPositions }

	var projectName: String {
		fileURL?.deletingPathExtension().lastPathComponent ?? untitledName
	}
	@ObservationIgnored private var untitledName = "Untitled"

	func newProject() {
		guard confirmDiscardChanges() else { return }
		load(Project(), from: nil, name: "Untitled")
	}

	/// Saves to the current file, or asks where. Returns whether it saved.
	@discardableResult
	func save() -> Bool {
		if let fileURL { return write(to: fileURL) } else { return saveAs() }
	}

	@discardableResult
	func saveAs() -> Bool {
		guard let url = FilePanels.saveURL(suggestedName: "\(projectName).json", type: .json)
		else { return false }
		return write(to: url)
	}

	private func write(to url: URL) -> Bool {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		do {
			try encoder.encode(project).write(to: url, options: .atomic)
			fileURL = url
			savedProject = project
			noteRecent(url)
			return true
		} catch {
			NSAlert(error: error).runModal()
			return false
		}
	}

	func open() {
		guard confirmDiscardChanges(),
			let url = FilePanels.openURL(types: [.json, .jsonc])
		else { return }
		open(url, confirmed: true)
	}

	/// Opens a project file. `confirmed` means unsaved changes were already dealt with.
	@discardableResult
	func open(_ url: URL, confirmed: Bool = false) -> Bool {
		guard confirmed || confirmDiscardChanges() else { return false }
		guard let data = try? Data(contentsOf: url), let loaded = Self.decodeProject(data) else {
			let alert = NSAlert()
			alert.messageText = "Couldn’t open “\(url.lastPathComponent)”"
			alert.informativeText =
				FileManager.default.fileExists(atPath: url.path)
				? "The file isn’t a Swiftr project." : "The file no longer exists."
			alert.runModal()
			forgetRecent(url)
			return false
		}
		load(loaded, from: url, name: url.deletingPathExtension().lastPathComponent)
		noteRecent(url)
		return true
	}

	/// `Swiftr path/to/project.json`: opens that file, or starts a new empty project that saves
	/// there if it doesn't exist yet. Relative paths are from the current directory.
	func openFromCommandLine(_ path: String) {
		let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
		var url = URL(fileURLWithPath: path, relativeTo: cwd).standardizedFileURL
		if url.pathExtension.isEmpty { url.appendPathExtension("json") }
		if FileManager.default.fileExists(atPath: url.path) {
			open(url, confirmed: true)
		} else {
			load(Project(), from: url, name: url.deletingPathExtension().lastPathComponent)
		}
	}

	private func load(_ loaded: Project, from url: URL?, name: String) {
		project = loaded
		savedProject = loaded
		fileURL = url
		untitledName = name
		selection = nil
		hiddenWindows = []
		inPlaceEdit = nil
		// Undo doesn't reach back into a different project.
		undoStack.removeAll()
		redoStack.removeAll()
	}

	/// Asks to save unsaved changes. Returns false if the user cancels.
	func confirmDiscardChanges() -> Bool {
		guard isDirty else { return true }
		let alert = NSAlert()
		alert.messageText = "Do you want to save the changes you made to “\(projectName)”?"
		alert.informativeText = "Your changes will be lost if you don’t save them."
		alert.addButton(withTitle: "Save")
		alert.addButton(withTitle: "Cancel")
		alert.addButton(withTitle: "Don’t Save")
		switch alert.runModal() {
		case .alertFirstButtonReturn: return save()
		case .alertThirdButtonReturn: return true
		default: return false
		}
	}

	func exportSwift() {
		FilePanels.save(
			CodeGenerator.generate(project), suggestedName: CodeGenerator.fileName(project),
			type: .swiftSource)
	}

	// MARK: Recent projects

	private func noteRecent(_ url: URL) {
		recentProjects =
			[url] + recentProjects.filter { $0.standardizedFileURL != url.standardizedFileURL }
		recentProjects = Array(recentProjects.prefix(10))
		RecentProjects.save(recentProjects)
	}

	private func forgetRecent(_ url: URL) {
		recentProjects.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
		RecentProjects.save(recentProjects)
	}

	func clearRecentProjects() {
		recentProjects = []
		RecentProjects.save(recentProjects)
	}

	/// Reads the current format, or converts a single-window layout from earlier versions.
	static func decodeProject(_ data: Data) -> Project? {
		let decoder = JSONDecoder()
		// JSON5 mode accepts // and /* */ comments (and trailing commas), for hand-annotated files.
		decoder.allowsJSON5 = true
		if let project = try? decoder.decode(Project.self, from: data) { return project }

		var window = DesignWindow()
		if let legacy = try? decoder.decode(LegacyDocument.self, from: data) {
			window.root = legacy.root
			if let w = legacy.window {
				window.settings.title = w.title
				window.settings.width = w.width
				window.settings.height = w.height
			}
		} else if let root = try? decoder.decode(Node.self, from: data) {
			window.root = root
		} else {
			return nil
		}
		return Project(windows: [window])
	}
}
