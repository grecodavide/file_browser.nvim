local M = {}
local utils = require("file_browser.utils")
local map = utils.map

---@type file_browser.State
local state = {
    options_to_restore = {
        fillchars = {
            floating = { eob = " " },
            original = {},
        },
    },
    buf_opts = {},
    win_opts = {},
    win_configs = {},
    results_width = 0,
    windows = {
        prompt_prefix = -1,
        prompt = -1,
        results_icon = -1,
        results = -1,
        preview = -1,
        padding = -1,
    },

    buffers = {
        prompt_prefix = -1,
        prompt = -1,
        results_icon = -1,
        results = -1,
        preview = -1,
        padding = -1,
    },

    entries = {},

    current_entry = -1,
    entries_nr = 0,
}

local update_prompt = function(cwd)
    utils.update_prompt(state, cwd)
end

local jump_next = function()
    utils.jump_to(1, state)
end

local jump_prev = function()
    utils.jump_to(-1, state)
end

local get_entries = function(cwd)
    utils.get_entries(state, cwd)
end

local set_options = function(conf)
    utils.set_options(state.options_to_restore, conf)
end

---@type file_browser.Config
M.opts = {
    start_insert = true,
    display_symlinks = true,
    group_dirs = true,
    width_scale = 0.92,
    height_scale = 0.92,
}

local windo = function(func)
    for kind, value in pairs(state.windows) do
        func(kind, value)
    end
end

local create_mappings = function()
    map("n", "<Esc>", "<cmd>fc!<CR>", state.buffers.prompt)
    map("i", "<C-f>", function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "i", false)
        vim.api.nvim_set_current_win(state.windows.results)
    end, state.buffers.prompt)
    map({ "n", "i" }, "<C-n>", jump_next, state.buffers.prompt)
    map({ "n", "i" }, "<C-p>", jump_prev, { state.buffers.prompt, state.buffers.results })
    map({ "n" }, "j", jump_next, { state.buffers.prompt, state.buffers.results })
    map({ "n" }, "k", jump_prev, { state.buffers.prompt, state.buffers.results })

    map({ "n", "i" }, "<CR>", function()
        vim.print(state.entries[state.current_entry])
    end, { state.buffers.prompt, state.buffers.results })

    map({ "n" }, "e", function()
        vim.api.nvim_set_current_win(state.windows.results)

        -- TODO: understand why this is necessary
        vim.api.nvim_buf_set_lines(state.buffers.results, -2, -1, false, {})
        vim.api.nvim_buf_set_lines(state.buffers.results_icon, -2, -1, false, {})
    end, state.buffers.prompt)

    map({ "n" }, "<Esc>", function()
        vim.api.nvim_set_current_win(state.windows.prompt)
    end, state.buffers.results)
end

local create_windows = function()
    windo(function(kind, value)
        state.win_configs, state.results_width = utils.get_win_configs(M.opts.width_scale, M.opts.height_scale)
        state.buf_opts, state.win_opts = utils.get_opts()

        if not vim.api.nvim_win_is_valid(value) then
            state.buffers[kind] = vim.api.nvim_create_buf(false, true)
            state.windows[kind] = vim.api.nvim_open_win(state.buffers[kind], false, state.win_configs[kind])

            for opt, v in pairs(state.buf_opts[kind]) do
                vim.bo[state.buffers[kind]][opt] = v
            end

            for opt, v in pairs(state.win_opts[kind]) do
                vim.wo[state.windows[kind]][opt] = v
            end
        end
    end)

    vim.bo[state.buffers.prompt].filetype = "prompt"

    create_mappings()

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = state.buffers.prompt,
        callback = function()
            set_options("original")
        end,
    })
    vim.api.nvim_create_autocmd("WinEnter", {
        buffer = state.buffers.results,
        callback = function()
            set_options("floating")
        end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = state.buffers.results,
        callback = function()
            local line = vim.api.nvim_win_get_cursor(state.windows.results)[1]
            vim.api.nvim_win_set_cursor(state.windows.results_icon, { line, 0 })
        end,
    })
end

---Opens the main window
---@param cwd string?: The path to search into. Default to cwd
M.open = function(cwd)
    utils.save_options(state.options_to_restore)
    create_windows()
    set_options("floating")
    cwd = cwd or vim.fn.getcwd()
    if cwd[#cwd] ~= "/" then
        cwd = cwd .. "/"
    end

    vim.api.nvim_set_current_win(state.windows.prompt)
    if M.opts.start_insert then
        vim.cmd([[startinsert]])
    end

    update_prompt(cwd)
    get_entries(cwd)

    local entry
    vim.api.nvim_buf_set_lines(state.buffers.results, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(state.buffers.results_icon, 0, -1, false, {})
    for row = 1, #state.entries do
        entry = state.entries[row]
        vim.api.nvim_buf_set_lines(state.buffers.results, row - 1, row - 1, false, { entry.text })
        vim.api.nvim_buf_set_lines(state.buffers.results_icon, row - 1, row - 1, false, { entry.icon.text })
        vim.api.nvim_buf_add_highlight(state.buffers.results_icon, 0, entry.icon.hl, row - 1, 0, -1)
        vim.api.nvim_buf_add_highlight(state.buffers.results, 0, entry.icon.hl, row - 1, 0, -1)
    end

    utils.jump_to(1, state, true)
end

---Sets up the plugin. Must always be called once
---@param opts file_browser.Config
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

M.setup({
    height_scale = 0.85,
})
M.open("~/.config/nvim")
-- M.open("~/shiny-potato/")

return M
