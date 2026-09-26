import SwiftUI

/// The symbol as a field: preview and name; click to open the symbol browser.
struct SymbolField: View {
	@Binding var name: String
	@State private var showBrowser = false

	var body: some View {
		Button {
			showBrowser.toggle()
		} label: {
			HStack(spacing: 7) {
				Image(systemName: name).frame(width: 16)
				Text(name).font(PanelStyle.font.monospaced()).lineLimit(1)
				Spacer(minLength: 0)
				Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(
					.secondary)
			}
			.fieldChrome()
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.popover(isPresented: $showBrowser, arrowEdge: .leading) {
			SymbolBrowser(selection: $name) { showBrowser = false }
		}
	}
}
