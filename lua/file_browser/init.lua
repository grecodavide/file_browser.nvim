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
        lhs = "<esc>",
        callback = "close",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-s>",
        callback = "mark_current",
    },
    {
        mode = "i",
        lhs = "<C-.>",
        callback = "cd",
    },
    {
        mode = "n",
        lhs = ".",
        callback = "cd",
    },
    {
        mode = "n",
        lhs = "r",
        callback = "rename",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-d>",
        callback = "scroll_preview_down",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-u>",
        callback = "scroll_preview_up",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-n>",
        callback = "jump_to",
        args = { 1 },
    },
    {
        mode = "n",
        lhs = "k",
        callback = "jump_to",
        args = { -1 },
    },
    {
        mode = { "n", "i" },
        lhs = "<C-p>",
        callback = "jump_to",
        args = { -1 },
    },
    {
        mode = "n",
        lhs = "j",
        callback = "jump_to",
        args = { 1 },
    },
    {
        mode = { "n", "i" },
        lhs = "<CR>",
        callback = "default",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-CR>",
        callback = "default",
        args = { true },
    },
    {
        mode = { "n", "i" },
        lhs = "<C-v>",
        callback = "open_split",
    },
    {
        mode = { "n", "i" },
        lhs = "<C-e>",
        callback = "create",
        -- args = { false },
    },
    {
        mode = { "n", "i" },
        lhs = "<C-x>",
        callback = "delete",
        args = { true },
    },
    {
        mode = "n",
        lhs = "d",
        callback = "delete",
        args = { true },
    },
    {
        mode = "n",
        lhs = "e",
        callback = "create",
    },
    {
        mode = { "n" },
        lhs = "x",
        callback = "delete",
        args = { true },
    },

    -- ##############
    -- ### prompt ###
    -- ##############
    {
        mode = { "i", "n" },
        lhs = "<BS>",
        callback = "goto_parent_or_delete",
    },
    {
        mode = { "i", "n" },
        lhs = "<C-m>",
        callback = "move_to_cwd",
    },
    {
        mode = { "i", "n" },
        lhs = "<C-y>",
        callback = "copy_to_cwd",
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
        for i, mapping in ipairs(default_mappings) do
            -- TODO:
            -- - if mapping exists dont do anything
            -- - if mapping exists partially, apply the partial mapping
            -- - if mapping does not exist apply all
        end

        M.opts.mappings = vim.tbl_extend("keep", M.opts.mappings, default_mappings)
    end

    set_up = true
end

return M
