--- Create cmd to get all entries matching a certain type in the given directory, and get its output
---@param path string: The path to search into
---@param type "f"|"d"|"l": The type to match.
---@return string[]: The output for this command
local function get_cmd(path, type)
    return vim.split(io.popen(string.format("cd %s && fd --exact-depth=1 -t %s", path, type), "r"):read("*a"), "\n")
end

local mini_icons = require("mini.icons")
local dir_hl = "MiniIconsBlue"
local dir_icon_text = ""
local link_icon_text = "󱅷"
local link_icon_hl = "MiniIconsBlue"

local utils = require("file_browser.utils")

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

local is_insert = function()
    return vim.fn.mode() == "i"
end

---@class file_browser.State
---@field windows file_browser.Layout: the Windows ID (initialized at invalid values)
---@field results_width number: the size of results width
---@field win_configs table<file_browser.LayoutElement, vim.api.keyset.win_config?>: The configs for all windows
---@field buffers file_browser.Layout: the Buffers ID (initialized at invalid values)
---@field entries file_browser.Entry[]: the Buffers ID (initialized at invalid values)
---@field current_entry number: The current entry. -1 (invalid) by default
---@field entries_nr number: The number of entries
---@field buf_opts table<file_browser.LayoutElement, vim.bo>
---@field win_opts table<file_browser.LayoutElement, vim.wo>
---@field options_to_restore table: options that should be restored globally once the windows get closed
---@field cwd string
local State = {}

---Returns a default state
---@return file_browser.State
function State:new()
    return setmetatable({
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
    }, self)
end

function State:get_prompt()
    return vim.api.nvim_buf_get_lines(self.buffers.prompt, 0, -1, false)[1]
end

function State:create_mappings()
    map("n", "<Esc>", "<cmd>fc!<CR>", self.buffers.prompt)

    map("i", "<C-f>", function()
        utils.normal_mode()
        vim.api.nvim_set_current_win(self.windows.results)
    end, self.buffers.prompt)
    map({ "n" }, "e", function()
        vim.api.nvim_set_current_win(self.windows.results)
    end, self.buffers.prompt)

    map({ "n", "i" }, "<C-n>", function()
        self:jump(1)
    end, self.buffers.prompt)
    map({ "n", "i" }, "<C-p>", function()
        self:jump(-1)
    end, { self.buffers.prompt, self.buffers.results })
    map({ "n" }, "j", function()
        self:jump(1)
    end, { self.buffers.prompt, self.buffers.results })
    map({ "n" }, "k", function()
        self:jump(-1)
    end, { self.buffers.prompt, self.buffers.results })

    map({ "n", "i" }, "<CR>", function()
        self:default_action()
    end, { self.buffers.prompt, self.buffers.results })
    map({ "n", "i" }, "<S-CR>", function()
        self:default_action(true)
    end, { self.buffers.prompt, self.buffers.results })

    map({ "i", "n" }, "<BS>", function()
        if self:get_prompt() == "" then
            self:goto_parent(is_insert())
        else
            -- mode = 'n' means "ignore remappings, behave regularly"
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", false)
        end
    end, { self.buffers.prompt })

    map({ "i", "n" }, "<BS>", function()
        self:goto_parent(is_insert())
    end, { self.buffers.results })

    map({ "n" }, "<Esc>", function()
        vim.api.nvim_set_current_win(self.windows.prompt)
    end, self.buffers.results)
end

function State:save_options()
    for opt, _ in pairs(self.options_to_restore) do
        if self.options_to_restore[opt].original == nil then
            self.options_to_restore[opt].original = vim.opt[opt]
        end
    end
end

---Sets options to either original or new value
---@param conf string
function State:set_options(conf)
    for option, value in pairs(self.options_to_restore) do
        vim.opt[option] = value[conf] or value.original
    end
end

function State:create_windows(width_scale, height_scale)
    self:save_options()
    self:windo(function(kind, value)
        self.win_configs, self.results_width = utils.get_win_configs(width_scale, height_scale)
        self.buf_opts, self.win_opts = utils.get_opts()

        if not vim.api.nvim_win_is_valid(value) then
            self.buffers[kind] = vim.api.nvim_create_buf(false, true)
            self.windows[kind] = vim.api.nvim_open_win(self.buffers[kind], false, self.win_configs[kind])
        end
        for opt, v in pairs(self.buf_opts[kind]) do
            vim.bo[self.buffers[kind]][opt] = v
        end

        for opt, v in pairs(self.win_opts[kind]) do
            vim.wo[self.windows[kind]][opt] = v
        end
    end)

    vim.bo[self.buffers.prompt].filetype = "prompt"

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = self.buffers.prompt,
        callback = function()
            self:set_options("original")
        end,
    })
    vim.api.nvim_create_autocmd("WinEnter", {
        buffer = self.buffers.results,
        callback = function()
            self:set_options("floating")
        end,
    })
    vim.api.nvim_create_autocmd("WinEnter", {
        buffer = self.buffers.prompt,
        callback = function()
            self:set_options("floating")
        end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = self.buffers.results,
        callback = function()
            local line = vim.api.nvim_win_get_cursor(self.windows.results)[1]
            vim.api.nvim_win_set_cursor(self.windows.results_icon, { line, 0 })
        end,
    })
end

--- Goes to a given directory, populating results and updating the state.
---@param cwd string: The path to cd to
---@param start_insert boolean?: Whether we should start in insert mode. Defaults to true
function State:cd(cwd, start_insert)
    self:reset_entries()
    if start_insert == nil or start_insert then
        vim.cmd([[startinsert]])
    end

    self:update_prompt(cwd, dir_hl)
    self:get_entries(self.cwd)

    local entry
    vim.api.nvim_buf_set_lines(self.buffers.results, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(self.buffers.results_icon, 0, -1, false, {})
    for row = 1, self.entries_nr do
        entry = self.entries[row]
        vim.api.nvim_buf_set_lines(self.buffers.results, row - 1, row - 1, false, { entry.text })
        vim.api.nvim_buf_set_lines(self.buffers.results_icon, row - 1, row - 1, false, { entry.icon.text })
        vim.api.nvim_buf_add_highlight(self.buffers.results_icon, 0, entry.icon.hl, row - 1, 0, -1)
        vim.api.nvim_buf_add_highlight(self.buffers.results, 0, entry.icon.hl, row - 1, 0, -1)
    end

    self:jump(1, true)
end

--- Focuses the prompt window
function State:focus()
    vim.api.nvim_set_current_win(self.windows.prompt)
end

---Jumps to a given entry in the list, by specifying an index
---@param index number: the index to jump to (relative or absolute)
---@param absolute boolean?: Whether the given index is absolute. Defaults to false
function State:jump(index, absolute)
    local new_curr
    if absolute then
        new_curr = index
    else
        new_curr = self.current_entry + index
    end

    if new_curr <= 0 then
        new_curr = self.entries_nr
    elseif new_curr > self.entries_nr then
        new_curr = 1
    end

    self.current_entry = new_curr

    vim.api.nvim_win_set_cursor(self.windows.results, { self.current_entry, 0 })
    vim.api.nvim_win_set_cursor(self.windows.results_icon, { self.current_entry, 0 })
end

---Updates the prompt, prompt prefix and cwd
---@param cwd string: The path to show as a prefix
---@param prefix_hl string: the hl group to be assigned to the prompt prefix
function State:update_prompt(cwd, prefix_hl)
    self.win_configs.prompt_prefix.width = #cwd
    self.win_configs.prompt.col = self.win_configs.prompt_prefix.col + #cwd + 1
    self.win_configs.prompt.width = self.results_width - (#cwd + 1)
    vim.api.nvim_win_set_config(self.windows.prompt_prefix, self.win_configs.prompt_prefix)
    vim.api.nvim_win_set_config(self.windows.prompt, self.win_configs.prompt)

    vim.api.nvim_buf_set_lines(self.buffers.prompt_prefix, 0, -1, false, { cwd })
    vim.api.nvim_buf_add_highlight(self.buffers.prompt_prefix, 0, prefix_hl, 0, 0, -1)

    self:set_cwd(cwd)
end

---Populates the state with the entries for the current directory
---@param cwd string
function State:get_entries(cwd)
    local directories = get_cmd(cwd, "d")
    for _, dir in pairs(directories) do
        if dir and dir ~= "" then
            table.insert(self.entries, {
                icon = {
                    text = dir_icon_text,
                    hl = dir_hl,
                },
                text = dir,
                is_dir = true,
            })
        end
    end

    local links = get_cmd(cwd, "l")
    for _, link in pairs(links) do
        if link and link ~= "" then
            table.insert(self.entries, {
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
            table.insert(self.entries, transform(file))
        end
    end

    self.entries_nr = #self.entries
    self.current_entry = 1
end

--- Calls given function on every window in the state
---@param func fun(string, number):any
function State:windo(func)
    for kind, value in pairs(self.windows) do
        func(kind, value)
    end
end

---Go to parent directory
---@param start_insert boolean?
function State:goto_parent(start_insert)
    local _, seps = self.cwd:gsub("/", "")
    if seps > 0 then
        local cwd = select(1, self.cwd:gsub("(.*)/.+$", "%1/"))
        self:cd(cwd, start_insert)
    end
end

--- Default action. Opens if file, cd if directory
---@param cd boolean?: should also change directory
function State:default_action(cd)
    local new_cwd = self.cwd .. self.entries[self.current_entry].text
    if self.entries[self.current_entry].is_dir then
        if cd then
            vim.fn.chdir(new_cwd)
        end
        self:cd(new_cwd, is_insert())
    else
        self:windo(function(_, value)
            vim.api.nvim_win_close(value, true)
        end)

        utils.normal_mode()
        if cd then
            vim.fn.chdir(self.cwd)
        end
        vim.cmd.edit(new_cwd)
    end
end

--- Empties the list of entries
function State:reset_entries()
    self.entries = {}
    self.entries_nr = 0
    self.current_entry = -1
end

---@private
function State:set_cwd(cwd)
    self.cwd = cwd
end

State.__index = State
return State
