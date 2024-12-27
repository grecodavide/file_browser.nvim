---@class file_browser.Config
---@field start_insert boolean?: Whether we should start in insert mode. Defaults to true
---@field cwd string?: Directory under which we should search
---@field display_symlinks boolean?: Wehter we should show symlinks or not. Defaults to true
---@field width_scale number?: Defaults to 0.92
---@field height_scale number?: Defaults to 0.92
---@field show_hidden boolean?: Defaults to true

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

-- ---@class file_browser.State
-- ---@field windows file_browser.Layout: the Windows ID (initialized at invalid values)
-- ---@field results_width number: the size of results width
-- ---@field win_configs table<file_browser.LayoutElement, vim.api.keyset.win_config?>: The configs for all windows
-- ---@field buffers file_browser.Layout: the Buffers ID (initialized at invalid values)
-- ---@field entries file_browser.Entry[]: the Buffers ID (initialized at invalid values)
-- ---@field current_entry number: The current entry. -1 (invalid) by default
-- ---@field entries_nr number: The number of entries
-- ---@field buf_opts table<file_browser.LayoutElement, vim.bo>
-- ---@field win_opts table<file_browser.LayoutElement, vim.wo>
-- ---@field options_to_restore table: options that should be restored globally once the windows get closed
-- ---@field cwd string
