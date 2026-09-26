import SwiftUI

struct Props: Codable, Equatable {
	var text = ""
	var placeholder = ""
	/// A labeled value's value, or an empty state's description.
	var detail = ""
	var systemImage = "star.fill"
	var isOn = false
	var value = 0.5
	/// A slider's range, and its step (nil slides smoothly).
	var sliderMin = 0.0
	var sliderMax = 1.0
	var sliderStep: Double? = nil
	var options = ["First", "Second", "Third"]
	var selectedIndex = 0
	var url = "https://www.apple.com"
	var indeterminate = false

	var fontSize = 13.0
	var weight: FontWeight = .regular

	var foreground: RGBA? = nil
	var background: RGBA? = nil
	/// The control accent (`.tint`): a switch's on color, a slider's track, a prominent button.
	var accent: RGBA? = nil
	var fill: RGBA = .blue

	var padding = 0.0
	var cornerRadius = 0.0
	var opacity = 1.0

	var spacing = 8.0
	var align: StackAlign = .center
	var scrollAxis: ScrollAxisOption = .vertical

	var width: Double? = nil
	var height: Double? = nil
	var fillWidth = false
	var fillHeight = false

	var action: ButtonAction? = nil
	var buttonDisplay: ButtonDisplay = .title
	var toggleStyle: ToggleStyleOption = .switch
	var symbolRendering: SymbolRendering = .monochrome
	/// A symbol's second and third layer colors, for palette rendering.
	var symbolSecondary: RGBA? = nil
	var symbolTertiary: RGBA? = nil
	/// The chosen `StyleVariant` id for kinds that have them; nil for the default.
	var variant: String? = nil
	/// The `@State` name for a control in generated code (nil derives one from its title).
	var variableName: String? = nil
	/// The project image an Image component shows.
	var imageID: UUID? = nil
	var contentMode: ContentModeOption = .fill
	/// Which part of an image stays in view when it's cropped (or where it sits when it fits).
	var imageAnchor: AnchorOption = .center
	/// Resizing an image keeps its proportions.
	var lockAspect = true
	var imageShape: ImageShape = .roundedRect
	var adjustments = ImageAdjustments()
	var border: BorderSettings? = nil
	var shadow: ShadowSettings? = nil
	var buttonStyle: ButtonStyleOption = .automatic
	var controlSize: ControlSizeOption = .regular
	var pickerStyle: PickerStyleOption = .menu
	var dateComponents: DateComponentsOption = .date

	var glass: GlassSettings? = nil
	/// Wrap a stack's children in a `GlassEffectContainer` so their glass blends and morphs.
	var glassContainer = false

	/// The slider's range, always valid (min below max) even if edited into an odd state.
	var sliderRange: ClosedRange<Double> {
		sliderMin < sliderMax ? sliderMin...sliderMax : sliderMin...(sliderMin + 1)
	}

	func sizeMode(_ axis: Axis) -> SizeMode {
		switch axis {
		case .horizontal: width != nil ? .fixed : fillWidth ? .fill : .hug
		case .vertical: height != nil ? .fixed : fillHeight ? .fill : .hug
		}
	}

	mutating func setSizeMode(_ mode: SizeMode, _ axis: Axis, fallback: Double) {
		switch axis {
		case .horizontal:
			width = mode == .fixed ? (width ?? fallback) : nil
			fillWidth = mode == .fill
		case .vertical:
			height = mode == .fixed ? (height ?? fallback) : nil
			fillHeight = mode == .fill
		}
	}
}

extension Props {
	/// Missing keys fall back to defaults, so files saved before a property existed still open.
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		let d = Props()
		func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
			(try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
		}
		self.init()
		text = v(.text, d.text)
		placeholder = v(.placeholder, d.placeholder)
		detail = v(.detail, d.detail)
		systemImage = v(.systemImage, d.systemImage)
		isOn = v(.isOn, d.isOn)
		value = v(.value, d.value)
		sliderMin = v(.sliderMin, d.sliderMin)
		sliderMax = v(.sliderMax, d.sliderMax)
		sliderStep = v(.sliderStep, d.sliderStep)
		options = v(.options, d.options)
		selectedIndex = v(.selectedIndex, d.selectedIndex)
		url = v(.url, d.url)
		indeterminate = v(.indeterminate, d.indeterminate)
		fontSize = v(.fontSize, d.fontSize)
		weight = v(.weight, d.weight)
		foreground = v(.foreground, d.foreground)
		background = v(.background, d.background)
		accent = v(.accent, d.accent)
		fill = v(.fill, d.fill)
		padding = v(.padding, d.padding)
		cornerRadius = v(.cornerRadius, d.cornerRadius)
		opacity = v(.opacity, d.opacity)
		spacing = v(.spacing, d.spacing)
		align = v(.align, d.align)
		scrollAxis = v(.scrollAxis, d.scrollAxis)
		width = v(.width, d.width)
		height = v(.height, d.height)
		fillWidth = v(.fillWidth, d.fillWidth)
		fillHeight = v(.fillHeight, d.fillHeight)
		action = v(.action, d.action)
		buttonDisplay = v(.buttonDisplay, d.buttonDisplay)
		toggleStyle = v(.toggleStyle, d.toggleStyle)
		symbolRendering = v(.symbolRendering, d.symbolRendering)
		symbolSecondary = v(.symbolSecondary, d.symbolSecondary)
		symbolTertiary = v(.symbolTertiary, d.symbolTertiary)
		variant = v(.variant, d.variant)
		variableName = v(.variableName, d.variableName)
		imageID = v(.imageID, d.imageID)
		contentMode = v(.contentMode, d.contentMode)
		imageAnchor = v(.imageAnchor, d.imageAnchor)
		lockAspect = v(.lockAspect, d.lockAspect)
		imageShape = v(.imageShape, d.imageShape)
		adjustments = v(.adjustments, d.adjustments)
		border = v(.border, d.border)
		shadow = v(.shadow, d.shadow)
		buttonStyle = v(.buttonStyle, d.buttonStyle)
		controlSize = v(.controlSize, d.controlSize)
		pickerStyle = v(.pickerStyle, d.pickerStyle)
		dateComponents = v(.dateComponents, d.dateComponents)
		glass = v(.glass, d.glass)
		glassContainer = v(.glassContainer, d.glassContainer)
	}
}

/// How a component sizes itself along one axis.
enum SizeMode: String, CaseIterable, Identifiable {
	case hug, fixed, fill
	var id: String { rawValue }
	var title: String { rawValue.capitalized }
}

/// What a button does when clicked in Preview mode and in the generated app.
enum ButtonAction: Codable, Equatable, Hashable {
	case openWindow(UUID)
	case closeWindow
}
