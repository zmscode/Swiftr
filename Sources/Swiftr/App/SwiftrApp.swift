import AppKit
import SwiftUI

@main
struct SwiftrApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	var body: some Scene {
		// All windows are managed by WindowManager. This never-shown scene only carries the menu commands.
		Window("Swiftr", id: "commands") { EmptyView() }
			.defaultLaunchBehavior(.suppressed)
			.commandsRemoved()
			.commands { AppCommands(model: appDelegate.model) }

		// Swiftr → Settings… (⌘,)
		Settings {
			SettingsView()
				.environment(appDelegate.model)
		}
	}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	let model = DesignModel()
	private var windowManager: WindowManager?

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Needed when launched with `swift run`, so the app gets a Dock icon and focus.
		NSApp.setActivationPolicy(.regular)
		// `Swiftr file.json` opens that file. Load it before the windows are created, so they open
		// with its design. Otherwise start with an empty project.
		if let path = Self.fileArgument() {
			model.openFromCommandLine(path)
		} else if UserDefaults.standard.string(forKey: SettingsView.launchKey)
			== SettingsView.Launch.reopenLast.rawValue
		{
			model.reopenLastProject()
		}
		windowManager = WindowManager(model: model)
		NSApp.activate(ignoringOtherApps: true)
	}

	/// Closing the last design window doesn't quit; its layers stay in the Library panel.
	/// The first command-line argument that isn't an option. Skips flags like `-NSDocumentRevisionsDebugMode YES`
	/// that Xcode and macOS add.
	private static func fileArgument() -> String? {
		var args = CommandLine.arguments.dropFirst()[...]
		while let arg = args.popFirst() {
			if arg.hasPrefix("-") {
				if let next = args.first, !next.hasPrefix("-") { args.removeFirst() }
				continue
			}
			return arg
		}
		return nil
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		model.confirmDiscardChanges() ? .terminateNow : .terminateCancel
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
		-> Bool
	{
		windowManager?.showPanels()
		return true
	}
}
