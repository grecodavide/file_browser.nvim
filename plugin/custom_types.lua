---@alias file_browser.mark_type "selected"|"cut"

---@class file_browser.Config
---@field start_insert boolean: Whether we should start in insert mode. Defaults to true
---@field display_symlinks boolean: Wehter we should show symlinks or not. Defaults to true
---@field width_scale number: Defaults to 0.92
---@field height_scale number: Defaults to 0.92
---@field show_hidden boolean: Defaults to true
---@field mark_icons table<file_browser.mark_type, file_browser.Icon>: Icons used for marks

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
