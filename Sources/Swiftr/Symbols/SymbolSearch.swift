import Foundation

/// Forgiving search over SF Symbol names. Every word typed must match the symbol somehow, best
/// matches first:
/// - an exact name, or a part of the name ("arrow" in "arrow.right"), or the start of one
/// - an abbreviation or everyday word ("cmd" → command, "settings" → gearshape, "number" → numerals)
/// - Apple's search keywords and categories ("arrow" → everything in Arrows)
/// - a near-miss typo ("chevorn") or the letters in order ("chvrn")
struct SymbolSearch: Sendable {
	struct Entry: Sendable {
		let name: String
		let parts: [String]
		let keywords: [String]
		let categories: Set<String>
	}

	let entries: [Entry]
	/// Category keys by lowercased title word ("arrows" → "arrows", "objects" → "objectsandtools").
	let categoryWords: [String: String]

	init(names: [String], keywords: [String: [String]], categories: [String: [String]], categoryTitles: [String: String]) {
		entries = names.map { name in
			Entry(
				name: name,
				parts: name.split(separator: ".").map(String.init),
				keywords: (keywords[name] ?? []).map { $0.lowercased() },
				categories: Set(categories[name] ?? []))
		}
		var words: [String: String] = [:]
		for (key, title) in categoryTitles {
			words[key.lowercased()] = key
			for word in title.lowercased().split(whereSeparator: { !$0.isLetter }) { words[String(word)] = key }
		}
		categoryWords = words
	}

	/// Matching symbol names, best first (ties keep Apple's order).
	func search(_ query: String) -> [String] {
		let tokens = query.lowercased()
			.split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," })
			.map(String.init)
		guard !tokens.isEmpty else { return entries.map(\.name) }
		let expanded = tokens.map { Token(text: $0, search: self) }
		// "heart fill" is most likely heart.fill itself, or something starting with it.
		let joined = tokens.joined(separator: ".")
		var scored: [(index: Int, score: Int)] = []
		for (i, entry) in entries.enumerated() {
			var total = entry.name == joined ? 300 : entry.name.hasPrefix(joined + ".") ? 60 : 0
			var matchesAll = true
			for token in expanded {
				let s = token.score(entry)
				if s == 0 {
					matchesAll = false
					break
				}
				total += s
			}
			if matchesAll { scored.append((i, total)) }
		}
		scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
		return scored.map { entries[$0.index].name }
	}

	/// One typed word, with what it also stands for.
	private struct Token {
		let text: String
		let synonyms: [String]
		let category: String?
		let numeric: Bool
		let letters: Bool

		init(text: String, search: SymbolSearch) {
			self.text = text
			synonyms = SymbolSearch.synonyms[text] ?? []
			// "arrow" → Arrows, "number" → Indices (by title word, or its plural).
			category = search.categoryWords[text] ?? search.categoryWords[text + "s"]
				?? SymbolSearch.categoryAliases[text]
			numeric = SymbolSearch.numberWords.contains(text)
			letters = SymbolSearch.letterWords.contains(text)
		}

		func score(_ e: Entry) -> Int {
			var best = direct(text, e)
			for synonym in synonyms { best = max(best, direct(synonym, e) - 5) }
			if let category, e.categories.contains(category) { best = max(best, 30) }
			if numeric, let first = e.parts.first, first.first?.isNumber == true { best = max(best, 70) }
			if letters, let first = e.parts.first, first.count == 1, first.first?.isLetter == true {
				best = max(best, 70)
			}
			if best == 0 && text.count >= 4 {
				// A typo in a name part: one edit away.
				let nearMiss: (String) -> Bool = { abs($0.count - text.count) <= 1 && Self.withinOneEdit($0, text) }
				if let first = e.parts.first, nearMiss(first) {
					best = 22
				} else if e.parts.contains(where: nearMiss) {
					best = 20
				}
			}
			// The letters in order, close together within one part ("chvrn" → chevron).
			if best == 0 && text.count >= 3 {
				if let first = e.parts.first, Self.isCompactSubsequence(text, of: first) {
					best = 12
				} else if e.parts.contains(where: { Self.isCompactSubsequence(text, of: $0) }) {
					best = 10
				}
			}
			return best
		}

		/// How well a word (or a multi-part synonym like "square.and.arrow.up") matches the name.
		private func direct(_ term: String, _ e: Entry) -> Int {
			if term.contains(".") {
				if e.name == term { return 100 }
				if e.name.hasPrefix(term + ".") { return 85 }
				return e.name.contains(term) ? 45 : 0
			}
			if e.name == term { return 100 }
			if e.parts.first == term { return 90 }
			if e.parts.contains(term) { return 80 }
			if e.parts.first?.hasPrefix(term) == true { return 65 }
			if e.parts.contains(where: { $0.hasPrefix(term) }) { return 55 }
			if e.keywords.contains(term) { return 50 }
			if e.keywords.contains(where: { $0.hasPrefix(term) }) { return 35 }
			if term.count >= 3 && e.name.contains(term) { return 40 }
			return 0
		}

		/// `needle`'s letters appear in order in `haystack`, starting with the same letter and
		/// spread over at most two extra letters (so "chvrn" matches chevron but "gear" isn't
		/// found in "greater").
		static func isCompactSubsequence(_ needle: String, of haystack: String) -> Bool {
			guard needle.first == haystack.first else { return false }
			let h = Array(haystack)
			var i = 0
			var last = -1
			for c in needle {
				while i < h.count && h[i] != c { i += 1 }
				guard i < h.count else { return false }
				last = i
				i += 1
			}
			return last + 1 <= needle.count + 2
		}

		/// Levenshtein distance ≤ 1.
		static func withinOneEdit(_ a: String, _ b: String) -> Bool {
			let a = Array(a), b = Array(b)
			if a == b { return true }
			if abs(a.count - b.count) > 1 { return false }
			var i = 0, j = 0, edits = 0
			while i < a.count && j < b.count {
				if a[i] == b[j] {
					i += 1
					j += 1
					continue
				}
				edits += 1
				if edits > 1 { return false }
				if a.count > b.count { i += 1 } else if a.count < b.count { j += 1 } else {
					// Also allow two neighboring letters swapped.
					if i + 1 < a.count && j + 1 < b.count && a[i] == b[j + 1] && a[i + 1] == b[j] {
						i += 2
						j += 2
						continue
					}
					i += 1
					j += 1
				}
			}
			return edits + (a.count - i) + (b.count - j) <= 1
		}
	}

	// MARK: Vocabulary

	static let numberWords: Set<String> = ["number", "numbers", "num", "digit", "digits", "numeral", "numerals"]
	static let letterWords: Set<String> = ["letter", "letters", "alphabet", "character"]
	static let categoryAliases: [String: String] = [
		"number": "indices", "numbers": "indices", "num": "indices", "digit": "indices",
		"media": "media", "people": "human", "person": "human", "security": "privacyandsecurity",
		"privacy": "privacyandsecurity", "car": "automotive", "transport": "transportation",
		"devices": "devices", "device": "devices", "health": "health", "fitness": "fitness",
	]

	/// Abbreviations and everyday words, and the symbol name parts they mean.
	static let synonyms: [String: [String]] = [
		// Keys and modifiers
		"cmd": ["command"], "opt": ["option"], "alt": ["option"], "ctrl": ["control"], "ctl": ["control"],
		"esc": ["escape"], "del": ["delete"], "backspace": ["delete.left"], "caps": ["capslock"],
		"enter": ["return"], "ret": ["return"], "kbd": ["keyboard"],
		// Everyday words
		"img": ["photo"], "image": ["photo"], "picture": ["photo"], "pic": ["photo"], "pics": ["photo"],
		"vid": ["video"], "movie": ["film", "video"], "msg": ["message", "bubble"], "chat": ["bubble", "message"],
		"txt": ["text"], "file": ["doc"], "files": ["doc", "folder"], "document": ["doc"],
		"settings": ["gearshape", "gear", "slider.horizontal.3"], "setting": ["gearshape"],
		"preferences": ["gearshape"], "prefs": ["gearshape"], "config": ["gearshape"], "gear": ["gearshape"],
		"home": ["house"], "search": ["magnifyingglass"], "find": ["magnifyingglass"],
		"zoom": ["magnifyingglass", "plus.magnifyingglass"],
		"mail": ["envelope"], "email": ["envelope"], "inbox": ["tray"],
		"user": ["person"], "profile": ["person.crop.circle"], "account": ["person.crop.circle"],
		"users": ["person.2"], "people": ["person.2", "person.3"], "group": ["person.3"],
		"bin": ["trash"], "delete": ["trash"], "remove": ["minus", "trash"], "add": ["plus"], "new": ["plus"],
		"close": ["xmark"], "cancel": ["xmark"], "x": ["xmark"], "done": ["checkmark"], "ok": ["checkmark"],
		"check": ["checkmark"], "tick": ["checkmark"], "yes": ["checkmark"], "no": ["xmark"],
		"warning": ["exclamationmark.triangle"], "alert": ["exclamationmark", "bell"], "error": ["exclamationmark", "xmark.octagon"],
		"help": ["questionmark"], "question": ["questionmark"], "info": ["info"],
		"like": ["heart", "hand.thumbsup"], "love": ["heart"], "fav": ["star"], "favorite": ["star"], "favourite": ["star"],
		"share": ["square.and.arrow.up"], "export": ["square.and.arrow.up"], "import": ["square.and.arrow.down"],
		"save": ["square.and.arrow.down", "tray.and.arrow.down"], "download": ["arrow.down.circle", "icloud.and.arrow.down"],
		"upload": ["arrow.up.circle", "icloud.and.arrow.up"], "refresh": ["arrow.clockwise"], "reload": ["arrow.clockwise"],
		"sync": ["arrow.triangle.2.circlepath"], "undo": ["arrow.uturn.backward"], "redo": ["arrow.uturn.forward"],
		"back": ["chevron.left", "arrow.left"], "forward": ["chevron.right", "arrow.right"], "next": ["chevron.right", "forward"],
		"previous": ["chevron.left", "backward"], "prev": ["chevron.left", "backward"],
		"arrow": ["chevron", "arrowtriangle", "arrowshape"], "arrows": ["arrow", "chevron"],
		"menu": ["line.3.horizontal", "filemenu"], "hamburger": ["line.3.horizontal"], "more": ["ellipsis"], "dots": ["ellipsis"],
		"edit": ["pencil", "square.and.pencil"], "write": ["pencil"], "compose": ["square.and.pencil"],
		"date": ["calendar"], "time": ["clock"], "timer": ["timer"], "schedule": ["calendar", "clock"],
		"music": ["music.note"], "song": ["music.note"], "audio": ["speaker", "waveform"], "sound": ["speaker", "waveform"],
		"volume": ["speaker"], "mute": ["speaker.slash"], "microphone": ["mic"], "record": ["record.circle", "mic"],
		"call": ["phone"], "internet": ["globe", "network"], "web": ["globe", "safari"], "website": ["globe"],
		"unlock": ["lock.open"], "secure": ["lock", "shield"], "password": ["key", "lock"], "security": ["lock", "shield"],
		"weather": ["cloud", "sun"], "night": ["moon"], "dark": ["moon"], "light": ["sun", "lightbulb"], "idea": ["lightbulb"],
		"power": ["power", "bolt"], "flash": ["bolt"], "energy": ["bolt"], "charge": ["battery", "bolt"],
		"gps": ["location"], "pin": ["mappin", "pin"], "place": ["mappin", "map"], "navigation": ["location", "map"],
		"shop": ["bag", "cart"], "buy": ["cart", "bag"], "money": ["dollarsign", "banknote"], "pay": ["creditcard"],
		"payment": ["creditcard"], "card": ["creditcard"], "bank": ["building.columns"], "price": ["tag", "dollarsign"],
		"chart": ["chart"], "graph": ["chart"], "stats": ["chart"], "analytics": ["chart"],
		"notification": ["bell"], "notifications": ["bell"], "show": ["eye"], "hide": ["eye.slash"],
		"visible": ["eye"], "hidden": ["eye.slash"], "view": ["eye"], "filter": ["line.3.horizontal.decrease"],
		"sort": ["arrow.up.arrow.down"], "grid": ["square.grid"], "list": ["list.bullet"], "table": ["tablecells"],
		"window": ["macwindow"], "mouse": ["computermouse"], "computer": ["desktopcomputer", "laptopcomputer"],
		"mac": ["desktopcomputer", "macbook"], "laptop": ["laptopcomputer", "macbook"], "phone": ["iphone", "phone"],
		"tablet": ["ipad"], "watch": ["applewatch"], "game": ["gamecontroller"], "games": ["gamecontroller"],
		"attach": ["paperclip"], "attachment": ["paperclip"], "copy": ["doc.on.doc"], "paste": ["doc.on.clipboard"],
		"clipboard": ["doc.on.clipboard", "clipboard"], "cut": ["scissors"], "print": ["printer"], "send": ["paperplane"],
		"reply": ["arrowshape.turn.up.left"], "box": ["shippingbox", "archivebox"], "package": ["shippingbox"],
		"bug": ["ladybug", "ant"], "code": ["chevron.left.forwardslash.chevron.right", "curlybraces"],
		"terminal": ["apple.terminal"], "brush": ["paintbrush"], "paint": ["paintbrush", "paintpalette"],
		"color": ["paintpalette", "eyedropper"], "colour": ["paintpalette", "eyedropper"], "text": ["textformat", "character"],
		"font": ["textformat"], "bold": ["bold"], "sparkle": ["sparkles"], "magic": ["wand.and.stars", "sparkles"],
		"ai": ["sparkles", "brain"], "health": ["heart", "cross"], "medical": ["cross", "stethoscope"],
		"car": ["car"], "travel": ["airplane", "suitcase"], "flight": ["airplane"], "food": ["fork.knife"],
		"coffee": ["cup.and.saucer"], "drink": ["cup.and.saucer", "wineglass"], "sport": ["figure", "sportscourt"],
		"run": ["figure.run"], "walk": ["figure.walk"], "fitness": ["figure", "dumbbell"],
	]
}
