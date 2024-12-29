local M = {}
M.dir_hl = "MiniIconsBlue"

local utils = require("file_browser.utils")

local set_up = false

M.is_set_up = function()
    return set_up
end

---@type file_browser.Config
M.opts = {
    start_insert = true,
    display_symlinks = true,
    group_dirs = true,
    width_scale = 0.92,
    height_scale = 0.92,
    preview_width = 0.4,
    max_prompt_size = 0.6,

    show_hidden = true,
    show_links = true,

    use_treesitter = true,

    marked_icons = {
        selected = {
            text = "█",
            hl = "MiniIconsYellow",
        },
        cut = {
            text = "█",
            hl = "MiniIconsRed",
        },
    },

    debounce = 200,
}
local state

---Opens the main window
---@param cwd string?: The path to search into. Default to cwd
M.open = function(cwd)
    state:focus()

    if cwd == nil or cwd == "" then
        cwd = vim.fn.getcwd()
    else
        cwd = vim.fn.expand(cwd)
    end

    if cwd:sub(#cwd) ~= "/" then
        cwd = cwd .. "/"
    end

    state:cd(cwd, M.opts.start_insert, M.show_hidden)
end

---Sets up the plugin. Must always be called once
---@param opts file_browser.Config
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

    state = require("file_browser.state"):new(M.opts)

    utils.save_options(state.options_to_restore)

    set_up = true
end

return M
