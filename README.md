# Swiftr

A drag-and-drop SwiftUI layout designer for macOS. Build a layout visually, then export it as SwiftUI code.

## Run

Requires macOS 26+ and Xcode 26+ (or the Swift 6.2 command line tools). Uses [ColorKit](https://github.com/kieranb662/SwiftUI-Color-Kit) for the color picker.

    cd Swiftr
    swift run Swiftr                # empty project
    swift run Swiftr MyApp.json     # open a project (or start a new one saved there)

With [just](https://github.com/casey/just): `just r` or `just r MyApp.json`.

Or open `Package.swift` in Xcode and press Run.

## Examples

`examples/` has five small projects: `Hello.json` (a greeting with a glass button), `SignIn.json` (a fixed-size login form), `Settings.json` (tabs of settings forms), `Mail.json` (a split view, plus an About window opened by a button) and `Conditions.json` (a toggle, slider and text field that show and hide other components; try it in Preview). Open one with `just r examples/Mail.json` or File → Open.

## Use

Swiftr has no main window. It opens two floating panels, **Library** (left) and **Inspector** (right), plus one real window for each window in your design.

- **Add a window:** ⌘N, or the window button in the Library's layers header. Each one is a real macOS window.
- **Add components:** drag a tile from the Library into a window, or onto a row in Layers. Double-click a tile to add it to the selected stack or the active window.
- **Select several:** Shift- or ⌘-click components in a window or in Layers, or drag across empty space in a window to draw a selection box (Shift-drag adds to the selection). Delete, copy, duplicate and grouping act on all of them.
- **Group:** with several selected, click a layout or group tile in the Library (VStack, HStack, Control Group, Menu, Form, Section, …) to put just those components into it. Also in the right-click menu and Arrange → Group In. Control Groups and Menus only accept buttons, toggles, pickers and links (menus also take dividers and sections).
- **Drop targeting:** a drop goes into the innermost container under the pointer that accepts it, at the spot shown by the blue insertion line.
- **Edit:** click a component in a window, or a row in Layers, then change it in the Inspector. Select a window's root (its row in Layers) to set title, size, title bar style, resizability, floating, and open-at-launch.
- **Double-click to edit in place:** text, buttons, links and toggles get an inline text field; symbols and labels open a searchable SF Symbols browser; shapes get resize handles (squares resize, round handles inside a rectangle's corners set the radius). Esc or clicking elsewhere finishes.
- **Liquid Glass:** in the Inspector, press + on "Liquid Glass" to add `.glassEffect` (regular or clear, shape, tint, interactive). Buttons also have Glass styles, and stacks can be a `GlassEffectContainer`. Generated code then targets macOS 26.
- **Panels:** the Library and Inspector hold tabs: Components, Layers, Inspector and Theme. Click a tab's header to fold it, drag the header to reorder tabs or move them to the other panel, and drag the edge between two open tabs to resize them. Window → Reset Panel Layout puts everything back.
- **Tooltips:** hover any control for a description; Settings → General sets how quickly they appear.
- **Theme:** the Theme tab sets the app's accent (every control's `.tint`), a palette of scheme colours (shown first in every colour picker) and a shared Liquid Glass look. Pick a ready-made scheme (Ocean, Forest, Sunset, Berry, Graphite) or your own. New glass follows the theme; untick "Follow project theme" to style it on its own. Generated code gets a `Theme` enum (`Theme.accent`, `Theme.palette`, `Theme.glass`).
- **Resize a window** by dragging its corner. The size is saved to the design.
- **Close a window** with its close button or ⌘W. It is hidden, not deleted; the eye button in Layers brings it back. Delete a window from its right-click menu.
- **Preview (⌘R, or ▶ in the Library):** windows behave like the finished app. Text fields, toggles and sliders work, and buttons can open or close windows (set a button's Action in the Inspector).
- **Themes:** pick a theme (Xcode, GitHub, Gruvbox, 0x96f, Darcula, Dracula, One Dark, Monokai, Nord, Solarized, Tokyo Night, Catppuccin) from the palette button in the Library or the code window. It colors the code and, unless turned off in the same menu, the Library and Inspector. Automatic follows the system and keeps the panels native.
- **Images:** drag an image file from Finder into a window (or use an Image component's Choose File…). Images are stored in the project file; rename or remove them under Images in the Inspector when nothing is selected. Generated code uses `Image("name")`: File → Export Images to Asset Catalog… writes them into your app's Assets.xcassets.
- **Navigation:** Tab View (with Tabs), Split View (sidebar and detail, optionally a middle column), Nav Stack and Nav Link. While editing, the Tab View shows the tab holding your selection. A Nav Link's destination appears when pushed in Preview; edit it through Layers.
- **Inspector:** shows only the sections that apply to the selected component. Style holds SwiftUI's styles for it (text field, date picker, progress, label, form, menu, control group and tab view styles, plus button, toggle and picker styles). Accent sets the control color (`.tint`), e.g. a switch's on color. Code (collapsed at the bottom) shows the component's SwiftUI with a copy button. Click a section title to fold it. Rename a component in the Inspector header or by double-clicking it in Layers; the name appears as a comment in the generated code.
- **Conditions:** make a component show only when a control in the same window is set. Select it, press + on Condition in the Inspector, and pick the control and test (e.g. "Dark mode is on", "Volume > 0.5", "Email is not empty"). While editing, conditional components are always shown with an orange "if" badge; in Preview (⌘R) they appear and disappear as you use the controls. Generated code uses named `@State` (from each control's title) and `if` statements.
- **Effects:** images can be cut to a rounded rectangle, circle or capsule, and have Adjustments (grayscale, saturation, brightness, contrast, blur). Anything drawn can have a Border and a Shadow (add them with + in the Inspector).
- **Rearranging in Layers:** drag rows to move components, or drop Library items onto rows. A line shows where it will land (a highlighted row means inside), and the design window previews the result live, with the moved component faded, before you let go.
- **Image sizing:** double-click an image for resize and corner handles. Keep Aspect Ratio (on by default) keeps proportions when resizing; Original Size resets it. Fit, Fill or Stretch set how the image fills its frame, and the anchor grid picks which part stays visible when Fill crops it.
- **Settings (⌘,):** what opens at launch (an empty project or the last one), the theme and whether it colors the panels, and how Export as Swift lays out code: one file, or `<App>App.swift` plus a file per view in a `Views/` folder, with or without `#Preview`, indented with 4 spaces, 2 spaces or tabs.
- **Moving windows:** middle-click and drag anywhere on a design window to move it.
- **Symbol search:** forgiving: abbreviations (`cmd` → command), everyday words (`settings` → gearshape), categories (`arrow`, `number`) and typos (`chevorn`) all work.
- **Projects:** ⌘S saves the whole design as a `.json` file. Opening also accepts `.jsonc`, and `//` or `/* */` comments you add by hand are allowed (they're not kept when Swiftr saves). Swiftr starts with an empty project; File → Open Recent lists recent ones. New, Open and Quit ask before discarding unsaved changes, and the Library panel's title shows the project name and "Edited".
- **Icon-only buttons:** set a button's display to Title, Icon or Title & Icon in the Inspector. Icon-only buttons keep their title as the accessibility label; double-click one to pick its symbol.
- **Code (⌘E):** a live window showing the complete generated app, with an `App` holding one `Window` scene per design window, then one view per window. Copy it or save it as a .swift file.

### Shortcuts

⌘Z / ⇧⌘Z undo and redo · ⌫ delete · Esc or ⌘↑ select parent · ⌘D duplicate · ⌘X ⌘C ⌘V cut, copy, paste · ⌘[ / ⌘] move up/down · ⌘G group in VStack, ⌥⌘G group in HStack, ⇧⌘G unwrap · ⌘R preview · ⌘E code · ⌥⌘L / ⌥⌘I show Library / Inspector · ⌘N new window · ⌥⌘N new project · ⌘O ⌘S ⇧⌘S open, save, save as · ⇧⌘E export as Swift.

While a text field is being edited, the edit shortcuts apply to the text instead of the design. Project files from earlier versions still open.

## Files

`Sources/Swiftr/`

| Folder | What's in it |
| --- | --- |
| `App/` | App entry point, app delegate, menu commands |
| `Windows/` | `WindowManager` (panels, design windows, code window) and `DesignWindowController` (one real window, synced with the model) |
| `Model/` | Plain data: component kinds, props and style options, Liquid Glass settings, the node tree, the project and its windows |
| `State/` | `DesignModel`: selection, editing, undo/redo, clipboard, window operations, save/open |
| `DesignWindow/` | What's drawn inside a design window: `NodeView` (editing overlays), `NodeContent` (the SwiftUI view for each component), style modifiers, in-place editors (inline text, shape handles), context menu |
| `Library/` | The Library panel: mode switch, component palette, windows and layers list |
| `Inspector/` | The Inspector panel: project, window and component properties |
| `DesignSystem/` | Compact controls shared by the panels: sections, fields, segmented controls, color row, ColorKit color popover |
| `Symbols/` | SF Symbols catalog (read from the system) and the searchable symbol browser |
| `Code/` | Code generator, live code window, syntax highlighter |
| `Support/` | Small helpers: extensions, file panels, text-focus routing |

To add a new component: add a case to `ComponentKind` (Model), give it defaults in `Node.make`, render it in `NodeContent` (DesignWindow), emit it in `CodeGenerator.emit` (Code), and add any inspector fields in `NodeInspector` (Inspector).
