// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Swiftr",
	platforms: [.macOS(.v26)],
	dependencies: [
		.package(url: "https://github.com/kieranb662/SwiftUI-Color-Kit", branch: "master")
	],
	targets: [
		.executableTarget(
			name: "Swiftr",
			dependencies: [.product(name: "ColorKit", package: "SwiftUI-Color-Kit")],
			path: "Sources/Swiftr",
			swiftSettings: [.swiftLanguageMode(.v5)]
		)
	]
)
