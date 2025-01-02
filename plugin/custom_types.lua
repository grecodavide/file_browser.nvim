---@alias file_browser.MarkIcons {selected: file_browser.Icon, cut:file_browser.Icon}

---@class file_browser.Config
---@field start_insert boolean: Whether we should start in insert mode. Defaults to true
---@field display_symlinks boolean: Wehter we should show symlinks or not. Defaults to true
---@field width_scale number: Defaults to 0.92
---@field height_scale number: Defaults to 0.92
---@field show_hidden boolean: Defaults to true
---@field show_links boolean: Defaults to true
---@field marked_icons file_browser.MarkIcons: Icons used for marks
---@field debounce number: debounce for preview (in ms)
---@field preview_width number: percentage of floating win to be used for preview
---@field max_prompt_size number: max size (percentage) of prompt prefix
---@field use_treesitter boolean: Defaults to true
---@field mappings file_browser.Mapping[]?: Mappings
---@field use_default_mappings boolean?: Use a default set of mappings. Defaults to true
---@field group_dirs boolean?: Whether directories should be grouped at the top
---@field respect_ignore boolean?: Should respect gitignore and similar. Defaults to true

---@class file_browser.Mapping
---@field mode string|string[]: the mode for the mapping
---@field lhs string: actual mapping
---@field region string|string[]: the region currently focused for the mapping to exist. Valid values are `results` and `prompt`
---@field callback string|function: callback. Can either be an existing action or a custom function
---@field args table?: optional arguments for callback

---@class file_browser.Icon
---@field text string: The icon text
---@field hl string: The Highlight group

---@class file_browser.Icons
---@field texts string[]: The icons text
---@field hls string[]: The Highlight groups

---@class file_browser.Entry
---@field text string: text
---@field icon file_browser.Icon: icon
---@field is_dir boolean: is it a directory?
---@field marked boolean: is it selected?
---@field marked_cut boolean: is it selected for cutting?

---@class file_browser.Entries
---@field texts string[]: text
---@field icons file_browser.Icons: icon
---@field dirs boolean[]: Whether the entry is a directory or not. Used to define hl/icon and grouping

---@class file_browser.Layout
---@field prompt_prefix integer
---@field prompt integer
---@field results integer
---@field results_icon integer
---@field preview integer
---@field padding integer

---@alias file_browser.LayoutElement "prompt_prefix"|"prompt"|"results"|"results_icon"|"preview"|"padding"

---@class file_browser.SavedFile
---@field entry file_browser.Entry: file
---@field pos [number, number]: (row, column) in file
---@field name string: what to show as name
