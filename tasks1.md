# tasks

## high priority

- [ ] `H004` | **Panel item tooltips**
	- Add hover tooltips for items in the panels
	- e.g. image adjustments (contrast, saturation etc)

## medium priority

- [ ] `M002` | **Conditional element display**
    - Create a Condition Editor panel that allows for node-based control-flow of components
    - e.g. if the slider value is above 0.5, disable this button
    - Only basic functionality to begin with
    - e.g. disable/enable components, hide/show components, compare values etc
- [ ] `M004` | **Project-wide colour theme support**
	- Add support for a project-wide colour theme
	- All accent colours should match a scheme
	- Chart colours (when added) should also match etc

## low priority

- [ ] `L001` | **Settings menu**
    - Add a `cmd + ,` settings menu
    - Move the Swiftr panel theme selection there
    - Add import/export settings
    - etc etc for other settings
- [ ] `L002` | **Chart support**
    - Add support for SwiftUI charts to components
    - May need a chart Editor panel
- [ ] `L003` | **Fuzzy SF Symbol search**
    - Add support for fuzzy search on SF Symbols
    - e.g. `cmd` should show `command`
    - e.g. `arrow` should show all arrows and similar symbols
    - e.g. `number` should show all numbers, in a circle, not, etc
- [ ] `L004` | **Additional save/load functionality + import/export**
    - Add support for a custom Swiftr file type (`.swftr`) that allows for further information than `.json`
    - Allow the exporting of `.swift` files directly from the code generated
    - Allow the importing of certain `.swift` files that don't contain specific patterns (yet)
- [ ] `L006` | **Further conditional element display**
	- Add support for different visualisations of conditional elements (for debug purposes)
	- Fix how unhiding elements can shift the positioning of existing elements
	- Add more complex conditional and control flow logic
	- e.g. loop support, condition chaining, update other components etc

#### completed tasks

##### high

- [x] `H001` | **Icon only buttons**
    - Add support for buttons that are just icons (and icons + text)
- [x] `H002` | **Save/Load functionality**
    - Add support for saving a layout as a `.json` file (for compatibility)
    - Allow opening of existing files using cli (e.g. `swift run Swiftr examples/Hello.json`)
    - Only basic functionality currently, custom format later, and importing/exporting `.swift` files directly
- [x] `H003` | **Image support**
    - Add the Image component, to import images
    - Add image adjustment functionality (crop, border, fill/fit functionality etc)
- [x] `H005` | **Library/Inspector panel size/positioning**
	- Update the Library and Inspector panels to be 85% the screen height (anchored to the top) and slightly inset from the screen sides - by default

##### medium

- [x] `M001` | **Navigation controls**
    - Add a Navigation list of components to the Library panel
- [x] `M003` | **Empty project default**
	- Swiftr opens on an empty project by default
- [x] `M005` | **Further Windows & Layers functionality**
	- Updat the Windows & Layers section to be more interactive with drag n drop
	- Show a preview of the updated positioning when the user is dragging a component

##### low
- [x] `L005` | **Component styling**
	- Update the default Toggle style to be the switch style (not checkbox)
	- Add additional styling options to the Inspector panel, for all relevant components (not just Toggle)
- [x] `L007` | **Element selection quality of life change**
	- Add support for clicking and dragging to highlight multiple components
	- If multiple components are selected, allow for them to be added into new grouping components with ease
- [x] `L008` | **Component accent colours**
	- Add support for changing the accent colours of components
	- e.g. radio button accent colour -> green
- [x] `L009` | **A basic examples directory**
	- Add an examples directory with some basic example `.json`'s
	- e.g. `Settings.json` (settings example), `SignIn.json` (sign in example) etc
