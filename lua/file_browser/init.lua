local M = {}
M.dir_hl = "MiniIconsBlue"
local mini_icons = require("mini.icons")
local dir_icon_text = ""
local link_icon_text = "󱅷"
local link_icon_hl = "MiniIconsBlue"

local utils = require("file_browser.utils")

---@type file_browser.State
local state = utils.default_state()

--- Creates a mapping for a specific buffer
---@param mode string|string[]: The mode(s) for the mapping
---@param lhs string: The actual mapping
---@param callback function|string: The callback for the mapping. Can also be a string like the regular mappings
---@param buffer number|number[]: The buffer for which the mapping must exist
local map = function(mode, lhs, callback, buffer)
    if type(buffer) == "table" then
        for _, buf in pairs(buffer) do
            vim.keymap.set(mode, lhs, callback, { buffer = buf, silent = true, noremap = true })
        end
    else
        vim.keymap.set(mode, lhs, callback, { buffer = buffer, silent = true, noremap = true })
    end
end

---Updated the prompt with the CWD
---@param cwd string: current path
M.update_prompt = function(cwd)
    -- M.update_prompt = function(prefix_bufnr, prefix_winnr, prefix_winconf, prompt_winnr, prompt_winconf, results_width, cwd)
    state.win_configs.prompt_prefix.width = #cwd
    state.win_configs.prompt.col = state.win_configs.prompt_prefix.col + #cwd + 1
    state.win_configs.prompt.width = state.results_width - (#cwd + 1)
    vim.api.nvim_win_set_config(state.windows.prompt_prefix, state.win_configs.prompt_prefix)
    vim.api.nvim_win_set_config(state.windows.prompt, state.win_configs.prompt)

    vim.api.nvim_buf_set_lines(state.buffers.prompt_prefix, 0, -1, false, { cwd })
    vim.api.nvim_buf_add_highlight(state.buffers.prompt_prefix, 0, M.dir_hl, 0, 0, -1)
end

---Makes preview focused item the given one
---@param pos number
---@param absolute boolean?: Whether it's a relative position or not. Defaults to false
M.jump_to = function(pos, absolute)
    local new_curr
    if absolute then
        new_curr = pos
    else
        new_curr = state.current_entry + pos
    end

    if new_curr <= 0 then
        new_curr = state.entries_nr
    elseif new_curr > state.entries_nr then
        new_curr = 1
    end

    state.current_entry = new_curr

    vim.api.nvim_win_set_cursor(state.windows.results, { state.current_entry, 0 })
    vim.api.nvim_win_set_cursor(state.windows.results_icon, { state.current_entry, 0 })
end

local jump_next = function()
    M.jump_to(1)
end
local jump_prev = function()
    M.jump_to(-1)
end

---Do for any window something
---@param func fun(string, number):any
local windo = function(func)
    for kind, value in pairs(state.windows) do
        func(kind, value)
    end
end

---Goes to normal mode
local normal_mode = function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "i", false)
end

---Go to parent directory
M.goto_parent = function()
    local _, seps = state.cwd:gsub("/", "")
    if seps > 0 then
        local cwd = select(1, state.cwd:gsub("(.*)/.+$", "%1/"))
        M.populate(cwd)
    end
end

---Default action
---@param cd boolean?: should also change directory
M.default_action = function(cd)
    local new_cwd = state.cwd .. state.entries[state.current_entry].text
    if state.entries[state.current_entry].is_dir then
        if cd then
            vim.fn.chdir(new_cwd)
        end
        M.populate(new_cwd)
    else
        windo(function(_, value)
            vim.api.nvim_win_close(value, true)
        end)

        normal_mode()
        if cd then
            vim.fn.chdir(state.cwd)
        end
        vim.cmd.edit(new_cwd)
    end
end

--- Create cmd to get all entries matching a certain type in the given directory, and get its output
---@param path string: The path to search into
---@param type "f"|"d"|"l": The type to match.
---@return string[]: The output for this command
local function get_cmd(path, type)
    return vim.split(io.popen(string.format("cd %s && fd --exact-depth=1 -t %s", path, type), "r"):read("*a"), "\n")
end

---Transforms text to icon and text couple
---@param entry string: the text gotten from a cmd
---@return file_browser.Entry
local function transform(entry)
    local icon_text, hl = mini_icons.get("file", entry)

    return {
        icon = { text = icon_text, hl = hl },
        text = entry,
    }
end

---Populates the state with the entries for the current directory
---@param cwd string
M.get_entries = function(cwd)
    local directories = get_cmd(cwd, "d")
    for _, dir in pairs(directories) do
        if dir and dir ~= "" then
            table.insert(state.entries, {
                icon = {
                    text = dir_icon_text,
                    hl = M.dir_hl,
                },
                text = dir,
                is_dir = true,
            })
        end
    end

    local links = get_cmd(cwd, "l")
    for _, link in pairs(links) do
        if link and link ~= "" then
            table.insert(state.entries, {
                icon = {
                    text = link_icon_text,
                    hl = link_icon_hl,
                },
                text = link,
                is_dir = false,
            })
        end
    end

    local files = get_cmd(cwd, "f")
    for _, file in pairs(files) do
        if file and file ~= "" then
            table.insert(state.entries, transform(file))
        end
    end

    state.entries_nr = #state.entries
end

M.save_options = function(options)
    for opt, _ in pairs(options) do
        if options[opt] == nil then
            options[opt].original = vim.opt[opt]
        end
    end
end

---Sets options to either original or new value
---@param conf string
local set_options = function(conf)
    for option, value in pairs(state.options_to_restore) do
        vim.opt[option] = value[conf] or value.original
    end
end

---@type file_browser.Config
M.opts = {
    start_insert = true,
    display_symlinks = true,
    group_dirs = true,
    width_scale = 0.92,
    height_scale = 0.92,
}

local create_mappings = function()
    map("n", "<Esc>", "<cmd>fc!<CR>", state.buffers.prompt)

    map("i", "<C-f>", function()
        normal_mode()
        vim.api.nvim_set_current_win(state.windows.results)
    end, state.buffers.prompt)
    map({ "n" }, "e", function()
        vim.api.nvim_set_current_win(state.windows.results)
    end, state.buffers.prompt)

    map({ "n", "i" }, "<C-n>", jump_next, state.buffers.prompt)
    map({ "n", "i" }, "<C-p>", jump_prev, { state.buffers.prompt, state.buffers.results })
    map({ "n" }, "j", jump_next, { state.buffers.prompt, state.buffers.results })
    map({ "n" }, "k", jump_prev, { state.buffers.prompt, state.buffers.results })

    map({ "n", "i" }, "<CR>", function()
        M.default_action()
    end, { state.buffers.prompt, state.buffers.results })
    map({ "n", "i" }, "<S-CR>", function()
        M.default_action(true)
    end, { state.buffers.prompt, state.buffers.results })
    map({ "n", "i" }, "<BS>", function()
        if vim.api.nvim_buf_get_lines(state.buffers.prompt, 0, -1, false)[1] == "" then
            M.goto_parent()
        else
            -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "i", false)
        end
        -- vim.print(state.entries[state.current_entry])
    end, { state.buffers.prompt, state.buffers.results })

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
        end
        for opt, v in pairs(state.buf_opts[kind]) do
            vim.bo[state.buffers[kind]][opt] = v
        end

        for opt, v in pairs(state.win_opts[kind]) do
            vim.wo[state.windows[kind]][opt] = v
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

M.reset_entries = function()
    state.entries = {}
    state.entries_nr = 0
    state.current_entry = -1
end

M.populate = function(cwd)
    M.reset_entries()
    state.cwd = cwd

    if M.opts.start_insert then
        vim.cmd([[startinsert]])
    end

    M.update_prompt(state.cwd)
    M.get_entries(state.cwd)

    local entry
    vim.api.nvim_buf_set_lines(state.buffers.results, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(state.buffers.results_icon, 0, -1, false, {})
    for row = 1, state.entries_nr do
        entry = state.entries[row]
        vim.api.nvim_buf_set_lines(state.buffers.results, row - 1, row - 1, false, { entry.text })
        vim.api.nvim_buf_set_lines(state.buffers.results_icon, row - 1, row - 1, false, { entry.icon.text })
        vim.api.nvim_buf_add_highlight(state.buffers.results_icon, 0, entry.icon.hl, row - 1, 0, -1)
        vim.api.nvim_buf_add_highlight(state.buffers.results, 0, entry.icon.hl, row - 1, 0, -1)
    end

    M.jump_to(1, true)
end

---Opens the main window
---@param cwd string?: The path to search into. Default to cwd
M.open = function(cwd)
    create_windows()
    vim.api.nvim_set_current_win(state.windows.prompt)
    set_options("floating")

    cwd = cwd or vim.fn.getcwd()

    if cwd:sub(#cwd) ~= "/" then
        cwd = cwd .. "/"
    end

    M.populate(cwd)
end

---Sets up the plugin. Must always be called once
---@param opts file_browser.Config
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
    utils.save_options(state.options_to_restore)
end

M.setup({
    height_scale = 0.85,
})
M.open("~/.config/nvim")
-- M.open("~/shiny-potato/")

return M
