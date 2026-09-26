import SwiftUI

extension Comparable {
	func clamped(to range: ClosedRange<Self>) -> Self {
		min(max(self, range.lowerBound), range.upperBound)
	}
}

extension View {
	@ViewBuilder
	func `if`<Result: View>(_ condition: Bool, _ transform: (Self) -> Result) -> some View {
		if condition { transform(self) } else { self }
	}
}

extension Color {
	/// Selection color in design windows; fixed rather than the accent color so it stays visible with Graphite.
	static let selectionBlue = Color(nsColor: .systemBlue)
}
