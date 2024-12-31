local M = {}
M.dir_hl = "MiniIconsBlue"

local utils = require("file_browser.utils")

local set_up = false

M.is_set_up = function()
    return set_up
end

local default_mappings = {
    {
        mode = "n",
        region = { "results", "prompt" },
        lhs = "<esc>",
        callback = "close",
    },
    {
        mode = { "n", "i" },
        region = { "results", "prompt" },
        lhs = "<C-s>",
        callback = "mark_current",
    },
    {
        mode = "i",
        region = { "results", "prompt" },
        lhs = "<C-.>",
        callback = "cd",
    },
    {
        mode = "n",
        region = "prompt",
        lhs = ".",
        callback = "cd",
    },
    {
        mode = "n",
        region = { "prompt" },
        lhs = "r",
        callback = "rename",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-d>",
        region = { "prompt", "results" },
        callback = "scroll_preview_up",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-u>",
        region = { "prompt", "results" },
        callback = "scroll_preview_down",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-n>",
        region = { "prompt", "results" },
        callback = "jump_to",
        args = { 1 },
    },
    {
        mode = "n",
        lhs = "k",
        region = { "prompt", "results" }, -- also results so that it wraps
        callback = "jump_to",
        args = { -1 },
    },
    {
        mode = { "n", "i" },
        lhs = "<C-p>",
        region = { "prompt", "results" },
        callback = "jump_to",
        args = { -1 },
    },
    {
        mode = "n",
        lhs = "j",
        region = { "prompt", "results" },
        callback = "jump_to",
        args = { 1 },
    },
    {
        mode = { "n", "i" },
        lhs = "<CR>",
        region = { "prompt", "results" },
        callback = "default",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-CR>",
        region = { "prompt", "results" },
        callback = "default",
        args = { true },
    },
    {
        mode = { "n", "i" },
        lhs = "<C-v>",
        region = { "prompt", "results" },
        callback = "open_split",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-e>",
        region = { "prompt", "results" },
        callback = "create",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-x>",
        region = { "prompt", "results" },
        callback = "delete",
        args = { true },
    },
    {
        mode = "n",
        lhs = "d",
        region = { "prompt", "results" },
        callback = "delete",
        args = { true },
    },
    {
        mode = "n",
        lhs = "e",
        region = "prompt",
        callback = "create",
    },
    {
        mode = { "n" },
        lhs = "x",
        region = "prompt",
        callback = "delete",
        args = { true },
    },

    -- ##############
    -- ### prompt ###
    -- ##############
    {
        mode = { "i", "n" },
        lhs = "<BS>",
        region = { "prompt" },
        callback = "goto_parent_or_delete",
    },

    {
        mode = { "i", "n" },
        lhs = "<C-m>",
        region = { "prompt", "results" },
        callback = "move_to_cwd",
    },
}

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

    use_default_mappings = true,

    mappings = {},
}

---@type file_browser.State
local state

---Opens the main window
---@param cwd string?: The path to search into. Default to cwd
M.open = function(cwd)
    state = require("file_browser.state"):new(M.opts)
    utils.save_options(state.options_to_restore)

    if cwd == nil or cwd == "" then
        cwd = vim.fn.getcwd()
    else
        cwd = vim.fn.expand(cwd)
    end

    if cwd:sub(#cwd) ~= "/" then
        cwd = cwd .. "/"
    end

    state:focus()
    state:cd(cwd, M.opts.start_insert)
end

M.get_state = function()
    return state
end

---Sets up the plugin. Must always be called once
---@param opts file_browser.Config
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

    if M.opts.use_default_mappings then
        M.opts.mappings = vim.tbl_extend("keep", M.opts.mappings, default_mappings)
    end

    set_up = true
end

return M
