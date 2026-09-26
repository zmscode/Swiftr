// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Swiftr",
	platforms: [.macOS(.v26)],
	dependencies: [
		.package(url: "https://github.com/kieranb662/SwiftUI-Color-Kit", branch: "master"),
		// Node editor for conditions. Pinned: it's young (0.x), and only the Conditions panel uses it.
		.package(url: "https://github.com/aaurelions/SwiftFlow", exact: "0.2.0"),
	],
	targets: [
		// Renames SwiftFlow's `Node` (which clashes with Swiftr's) for use from the app.
		.target(
			name: "FlowBridge",
			dependencies: [.product(name: "SwiftFlow", package: "SwiftFlow")],
			path: "Sources/FlowBridge"
		),
		.executableTarget(
			name: "Swiftr",
			dependencies: [
				.product(name: "ColorKit", package: "SwiftUI-Color-Kit"),
				.product(name: "SwiftFlow", package: "SwiftFlow"),
				"FlowBridge",
			],
			path: "Sources/Swiftr",
			swiftSettings: [.swiftLanguageMode(.v5)]
		),
	]
)
