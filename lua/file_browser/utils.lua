local M = {}

M.dir_hl = "MiniIconsBlue"
local mini_icons = require("mini.icons")
local dir_icon_text = ""
local link_icon_text = "󱅷"
local link_icon_hl = "MiniIconsBlue"

--- Creates a mapping for a specific buffer
---@param mode string|string[]: The mode(s) for the mapping
---@param lhs string: The actual mapping
---@param callback function|string: The callback for the mapping. Can also be a string like the regular mappings
---@param buffer number|number[]: The buffer for which the mapping must exist
M.map = function(mode, lhs, callback, buffer)
    if type(buffer) == "table" then
        for _, buf in pairs(buffer) do
            vim.keymap.set(mode, lhs, callback, { buffer = buf, silent = true, noremap = true })
        end
    else
        vim.keymap.set(mode, lhs, callback, { buffer = buffer, silent = true, noremap = true })
    end
end

---Updated the prompt with the CWD
---@param state file_browser.State: the prompt prefix's buffer
---@param cwd string: current path
M.update_prompt = function(state, cwd)
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
M.jump_to = function(pos, state, absolute)
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

---Gets all the options for the windows
---@return table<string, vim.bo>, table<string, vim.wo>: A table containing, for each window, all buffer and windows options
M.get_opts = function()
    return {
        prompt_prefix = {},
        prompt = {
            bufhidden = "wipe",
        },
        results = {},
        results_icon = {},
        preview = {},

        padding = {},
    }, {
        prompt_prefix = {
            cursorline = false,
            number = false,
            relativenumber = false,
            signcolumn = "no",
        },
        prompt = {
            cursorline = false,
            number = false,
            relativenumber = false,
            signcolumn = "no",
        },
        results = {
            cursorline = true,
            number = false,
            relativenumber = false,
            signcolumn = "no",
        },
        results_icon = {
            cursorline = true,
            number = false,
            relativenumber = false,
            signcolumn = "no",
        },
        preview = {
            cursorline = false,
        },

        padding = {
            cursorline = true,
        },
    }
end

---Do for any window something
---@param state file_browser.State
---@param func fun(string, number):any
M.windo = function(state, func)
    for kind, value in pairs(state.windows) do
        func(kind, value)
    end
end

M.normal_mode = function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "i", false)
end

---@param state file_browser.State
M.goto_parent = function(state)
    local _, seps = state.cwd:gsub("/", "")
    if seps > 0 then
        local cwd = select(1, state.cwd:gsub("(.*)/.+$", "%1/"))
        require("file_browser").populate(cwd)
    end
end

---Default action
---@param state file_browser.State
M.default_action = function(state)
    local new_cwd = state.cwd .. state.entries[state.current_entry].text
    if state.entries[state.current_entry].is_dir then
        require("file_browser").populate(new_cwd)
    else
        -- vim.api.nvim_win_close(state.windows.prompt, true)
        -- vim.api.nvim_win_close(state.windows.prompt_prefix, true)
        -- vim.api.nvim_win_close(state.windows.results, true)
        -- vim.api.nvim_win_close(state.windows.results_icon, true)
        -- vim.api.nvim_win_close(state.windows.padding, true)
        -- vim.api.nvim_win_close(state.windows.preview, true)
        M.windo(state, function(_, value)
            vim.api.nvim_win_close(value, true)
        end)

        M.normal_mode()
        vim.cmd.edit(new_cwd)
    end
end

---Gets the windows configuration, used to create such windows
---@param width_scale number: percentage of width. Defaults 0.9
---@param height_scale number: percentage of height. Defaults 0.9
---@param preview_scale number?: percentage of preview. Defaults to 0.3
---@return table<string, vim.api.keyset.win_config>, number: The windows config and the size of the results
M.get_win_configs = function(width_scale, height_scale, preview_scale)
    width_scale = width_scale
    height_scale = height_scale
    preview_scale = preview_scale or 0.3

    local width = vim.o.columns
    local height = vim.o.lines

    -- bitshift because the padding is on both sides, so half the remaining space
    local base_row = bit.rshift(math.floor(height * (1 - height_scale)), 1)
    local base_col = bit.rshift(math.floor(width * (1 - width_scale)), 1)

    width = math.ceil(width * width_scale)
    height = math.ceil(height * height_scale)

    local preview_width = math.ceil(width * preview_scale)
    local results_width = math.ceil(width * (1 - preview_scale))
    -- 1 prompt, 2 prompt border, 1 border results
    local results_height = height - 4

    return {
        prompt_prefix = {
            relative = "editor",
            width = 1,
            height = 1,
            row = base_row,
            col = base_col,
            border = { "┌", "─", "─", "", "─", "─", "├", "│" },
            zindex = 3,
        },
        prompt = {
            relative = "editor",
            width = results_width,
            height = 1,
            row = base_row,
            col = base_col,
            border = { "─", "─", "┐", "│", "┤", "─", "─", "" },
            zindex = 2,
        },
        padding = {
            relative = "editor",
            width = 1,
            height = results_height,
            row = base_row + 3,
            col = base_col,
            border = { "│", " ", " ", " ", "─", "─", "└", "│" },
            zindex = 1,
            focusable = false,
        },
        results_icon = {
            relative = "editor",
            width = 2,
            height = results_height,
            row = base_row + 3,
            col = base_col + 2,
            border = { " ", " ", " ", "", " ", "─", "─", " " },
            zindex = 2,
            focusable = false,
        },
        results = {
            relative = "editor",
            width = results_width - 5, -- padding (1), results_icon (2), two double borders (2 each)
            height = results_height,
            row = base_row + 3,
            col = base_col + 5,
            border = { " ", " ", "│", "│", "┘", "─", "─", "" },
            zindex = 3,
        },
        preview = {
            relative = "editor",
            width = preview_width,
            height = results_height + 3,
            row = base_row,
            col = base_col + results_width + 1,
            border = "single",
            zindex = 1,
            focusable = false,
        },
    },
        results_width
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

M.get_entries = function(state, cwd)
    -- state.entries.files = vim.iter(get_cmd(cwd, "f")):map(transform)
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

---Saves the original values of the options that will need to be modified by the plugin
---@param options table
M.save_options = function(options)
    for opt, _ in pairs(options) do
        if options[opt] == nil then
            options[opt].original = vim.opt[opt]
        end
    end
end

---Sets options to either original or new value
---@param conf string
M.set_options = function(options, conf)
    for option, value in pairs(options) do
        vim.opt[option] = value[conf] or value.original
    end
end

---Creates a default state value
---@return file_browser.State
M.default_state = function()
    return {
        cwd = "",
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
end

return M
