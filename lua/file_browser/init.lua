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

    respect_ignore = true,
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

local function contains(tbl, value)
    for _, e in ipairs(tbl) do
        if e == value then
            return true
        end
    end
    return false
end
local function contains_key(tbl, value)
    for key, _ in pairs(tbl) do
        if key == value then
            return true
        end
    end
    return false
end

local function get_user_mappings()
    local already_seen = {}

    for _, mapping in ipairs(M.opts.mappings) do
        local lhs = mapping.lhs
        if already_seen[lhs] == nil then
            already_seen[lhs] = {}
        end

        if type(mapping.mode) == "string" then
            table.insert(already_seen[lhs], mapping.mode)
        else
            vim.iter(mapping.mode):each(function(mode)
                table.insert(already_seen[lhs], mode)
            end)
        end
    end

    return already_seen
end

local function extend_mappings(already_seen)
    for _, mapping in ipairs(default_mappings) do
        if contains_key(already_seen, mapping.lhs) then
            if type(mapping.mode) == "string" then
                if not contains(already_seen[mapping.lhs], mapping.mode) then
                    table.insert(M.opts.mappings, mapping)
                end
            else
                local m = {
                    lhs = mapping.lhs,
                    callback = mapping.callback,
                    mode = {},
                }

                ---@diagnostic disable-next-line: param-type-mismatch
                for _, mode in ipairs(mapping.mode) do
                    if not contains(already_seen[mapping.lhs], mode) then
                        table.insert(m.mode, mode)
                    end
                end
                if #mapping.lhs > 0 then
                    table.insert(M.opts.mappings, m)
                end
            end
        else
            table.insert(M.opts.mappings, mapping)
        end
    end
end

---Sets up the plugin. Must always be called once
---@param opts file_browser.Config
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

    if M.opts.use_default_mappings then
        local already_seen = get_user_mappings()
        extend_mappings(already_seen)
    end

    set_up = true
end

return M
