import AppKit
import SwiftUI

/// Searchable grid of SF Symbols with previews. Clicking a symbol applies it immediately;
/// double-clicking (or Return) applies it and closes.
struct SymbolBrowser: View {
	@Binding var selection: String
	var onDone: () -> Void = {}

	@State private var query = ""
	@State private var category = "all"
	@State private var hovered: String?
	@State private var results: [String] = []
	@FocusState private var searchFocused: Bool

	private let columns = [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: 4)]

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 6) {
				Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
				TextField("Search \(SymbolCatalog.names.count) symbols", text: $query)
					.textFieldStyle(.plain)
					.focused($searchFocused)
					.onSubmit(onDone)
					.help("Forgiving search: try abbreviations (cmd), everyday words (settings, close), categories (arrow, number) or near-misses (chevorn)")
				Menu {
					ForEach(SymbolCatalog.categories) { c in
						Button {
							category = c.key
						} label: {
							Label(c.title, systemImage: c.icon)
						}
					}
				} label: {
					Text(SymbolCatalog.categories.first { $0.key == category }?.title ?? "All")
						.font(.caption)
				}
				.menuStyle(.borderlessButton)
				.fixedSize()
			}
			.padding(10)

			Divider()

			ScrollViewReader { proxy in
				ScrollView {
					LazyVGrid(columns: columns, spacing: 4) {
						ForEach(results, id: \.self) { name in
							SymbolCell(name: name, isSelected: name == selection)
								.id(name)
								.onHover { hovered = $0 ? name : (hovered == name ? nil : hovered) }
								.onTapGesture {
									selection = name
									if NSApp.currentEvent?.clickCount == 2 { onDone() }
								}
						}
					}
					.padding(8)
				}
				.onAppear { proxy.scrollTo(selection, anchor: .center) }
			}

			Divider()

			HStack {
				Image(systemName: hovered ?? selection).frame(width: 18)
				Text(hovered ?? selection)
					.font(.caption.monospaced())
					.lineLimit(1)
					.textSelection(.enabled)
				Spacer()
				Text("\(results.count)").font(.caption).foregroundStyle(.tertiary)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
		}
		.frame(width: 400, height: 440)
		.onAppear {
			results = SymbolCatalog.search(query, category: category)
			searchFocused = true
		}
		.onChange(of: query) { results = SymbolCatalog.search(query, category: category) }
		.onChange(of: category) { results = SymbolCatalog.search(query, category: category) }
	}
}

private struct SymbolCell: View {
	@Environment(\.panelTheme) private var panelTheme
	let name: String
	let isSelected: Bool
	@State private var isHovered = false

	var body: some View {
		Image(systemName: name)
			.font(.system(size: 18))
			.frame(width: 44, height: 40)
			.background(
				RoundedRectangle(cornerRadius: 6)
					.fill(
						isSelected
							? panelTheme.accent : Color.primary.opacity(isHovered ? 0.08 : 0))
			)
			.foregroundStyle(isSelected ? .white : .primary)
			.contentShape(Rectangle())
			.onHover { isHovered = $0 }
			.help(name)
	}
}
