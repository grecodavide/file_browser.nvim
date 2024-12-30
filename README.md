# file_browser.nvim

This plugin aims to provide a file browser similar to the one provided by telescope extension,
without necessarily using telescope.

## External dependencies
- `fzf`
- `fd`

## Currently implemented
- Base filesystem navigation
- Prompt prefix with proper trimming
- preview with debounce and (optional) treesitter highlighting
- opening files (optionally in vsplit)
- fuzzy filtering with `fzf`
- preview scrolling

## WIP
- [x] Create file action (currently only if there is no match for the prompt). Should also support nesting
- [x] Delete file action
- [ ] Move/rename action
- [x] User customization for mappings
- [ ] (optional) give ability to directly edit results


> [!warn]
> functions that modify a buffer's text must be called synchronously, so 
> be careful hovering too big of a file, as it could lock you for a while
