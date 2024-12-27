local M = {}
M.dir_hl = "MiniIconsBlue"

local utils = require("file_browser.utils")

---@type file_browser.Config
M.opts = {
    start_insert = true,
    display_symlinks = true,
    group_dirs = true,
    width_scale = 0.92,
    height_scale = 0.92,
    show_hidden = true,
}
local state

---Opens the main window
---@param cwd string?: The path to search into. Default to cwd
M.open = function(cwd)
    state:create_windows(M.opts.width_scale, M.opts.height_scale)
    state:focus()

    cwd = cwd or vim.fn.getcwd()

    if cwd:sub(#cwd) ~= "/" then
        cwd = cwd .. "/"
    end

    state:cd(cwd, M.opts.start_insert, M.show_hidden)
    state:create_mappings()
end

---Sets up the plugin. Must always be called once
---@param opts file_browser.Config
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

    state = require("file_browser.state"):new()
    utils.save_options(state.options_to_restore)
end

M.setup({
    height_scale = 0.85,
})

M.open("~/.config/nvim")
-- M.open("~/shiny-potato/")

return M
