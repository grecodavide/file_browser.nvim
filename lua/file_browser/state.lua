local last_win
local set_hl = require("file_browser.utils").set_hl

--- Create cmd to get all entries matching a certain type in the given directory, and get its output
---@param path string: The path to search into
---@param type "f"|"d"|"l"|"a": The type to match.
---@param show_hidden boolean: Whether to show hidden files
---@param respect_ignore boolean?: Respect gitignore. Defaults to true
---@return string[]: The output for this command
local function get_from_cmd(path, type, show_hidden, respect_ignore)
    local cmd = string.format(
        "cd '%s' && fd --exact-depth=1 %s%s%s",
        path,
        show_hidden and "--hidden " or "",
        respect_ignore == false and "-I " or "",
        type ~= "a" and "-t " .. type or ""
    )

    return vim.split(io.popen(cmd):read("*a"), "\n")
end

local mini_icons = require("mini.icons")
local dir_hl = "MiniIconsBlue"
local dir_icon_text = ""

local utils = require("file_browser.utils")
local defer = utils.defer

---Transforms text to icon and text couple
---@param entry string: the text gotten from a cmd
---@return file_browser.Entry
local function transform(entry)
    local icon_text, hl = mini_icons.get("file", entry)

    return {
        icon = { text = icon_text, hl = hl },
        text = entry,
        is_dir = false,
        marked = false,
    }
end

---@class file_browser.State
---@field windows file_browser.Layout: the Windows ID (initialized at invalid values)
---@field results_width number: the size of results width
---@field win_configs table<file_browser.LayoutElement, vim.api.keyset.win_config?>: The configs for all windows
---@field buffers file_browser.Layout: the Buffers ID (initialized at invalid values)
---@field entries file_browser.Entry[]: the Buffers ID (initialized at invalid values)
---@field entries_nr number: The number of entries
---@field display_entries file_browser.Entry[]: the Buffers ID (initialized at invalid values)
---@field display_current_entry_idx number: The current entry. -1 (invalid) by default
---@field display_entries_nr number: The number of entries
---@field buf_opts table<file_browser.LayoutElement, vim.bo>
---@field win_opts table<file_browser.LayoutElement, vim.wo>
---@field options_to_restore table: options that should be restored globally once the windows get closed
---@field cwd string: current directory of the plugin. Note that it won't always coincide with nvim's
---@field show_hidden boolean: Whether to show dotfiles
---@field width_scale number: Width percentage for the plugin
---@field height_scale number: Height percentage for the plugin
---@field preview_width number: Preview percentage (relative to the whole plugin's width)
---@field max_prompt_size number: Max size (in percentage) for promtp prefix. If the prompt prefix is longer than this, the shown path will be trimmed
---@field marked_icons file_browser.Icon: Icons to use to define marked entries
---@field debounce number: ms to wait before updating the preview
---@field use_treesitter boolean: preview with treesitter/regular syntax
---@field mappings file_browser.Mapping[]: List of mappings to create
---@field group_dirs boolean: Whether the directories should be grouped at the top
---@field marked table<string, file_browser.Entry>: list of marked items, based on cwd
---@field actions file_browser.Actions
---@field respect_ignore boolean: Respect gitignore and similar
local State = {}

---Returns a default state, also binding `actions` to it
---@param opts file_browser.Config
---@return file_browser.State
function State:new(opts)
    local marked_icons = {
        text = string.format(" %s", opts.marked_icons.selected.text),
        hl = opts.marked_icons.selected.hl,
    }

    local tbl = setmetatable(
        ---@type file_browser.State
        {
            cwd = "",
            options_to_restore = {
                fillchars = {
                    floating = { eob = " " },
                },
                listchars = {
                    floating = { tab = "  ", trail = " ", nbsp = " " },
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
            entries_nr = 0,

            display_entries = {},
            display_entries_nr = 0,
            display_current_entry_idx = -1,

            width_scale = opts.width_scale,
            height_scale = opts.height_scale,
            preview_width = opts.preview_width,
            max_prompt_size = opts.max_prompt_size,

            marked_icons = marked_icons,

            show_hidden = opts.show_hidden,
            respect_ignore = opts.respect_ignore,

            debounce = opts.debounce,
            display_links = opts.show_links,
            use_treesitter = opts.use_treesitter,

            mappings = opts.mappings,
            group_dirs = opts.group_dirs,

            marked = {},
        },
        self
    )

    tbl.actions = require("file_browser.actions"):new(tbl)
    return tbl
end

---@private
---Create entries in given cwd
---@param cwd string
---@param tbl table?: if not given defaults to `self.entries`
function State:_create_entries(cwd, tbl)
    local results = get_from_cmd(cwd, "a", self.show_hidden, self.respect_ignore)
    local last_dir = 1
    tbl = tbl or self.entries

    for _, res in ipairs(results) do
        if res and res ~= "" then -- it's a valid entry
            if res:sub(#res) == "/" then -- it's a directory
                local entry = {
                    icon = {
                        text = dir_icon_text,
                        hl = dir_hl,
                    },
                    text = res,
                    is_dir = true,
                    marked = false,
                }

                if self.group_dirs then
                    table.insert(tbl, last_dir, entry)
                    last_dir = last_dir + 1
                else
                    table.insert(tbl, entry)
                end
            else
                table.insert(tbl, transform(res))
            end
        end
    end
end

local mappings = {}

--- Parses a `file_browser.Mapping` to an actual nvim mapping, setting it up
function State:_parse_mapping()
    vim.iter(self.mappings):each(function(mapping)
        local args = vim.deepcopy(mapping.args) or {}

        local callback

        if type(mapping.callback) == "string" then
            callback = self.actions[mapping.callback]
            if callback == nil then
                local msg = string.format("Error trying to set up mapping %s. Invalid action: %s", mapping.lhs, mapping.callback)
                vim.notify(msg, vim.log.levels.ERROR, {})
                return
            end
            table.insert(args, 1, self.actions)
        else
            callback = mapping.callback
        end

        pcall(vim.keymap.del, mapping.mode, mapping.lhs, { buffer = self.buffers.prompt })

        table.insert(mappings, { mode = mapping.mode, lhs = mapping.lhs, callback = callback, args = args })
    end)
end

function State:get_prompt()
    return vim.api.nvim_buf_get_lines(self.buffers.prompt, 0, -1, false)[1]
end

function State:get_current_entry()
    return self.display_entries[self.display_current_entry_idx]
end

function State:create_mappings()
    vim.iter(mappings):each(function(mapping)
        vim.keymap.set(mapping.mode, mapping.lhs, function()
            mapping.callback(unpack(mapping.args))
        end, { buffer = self.buffers.prompt })
    end)
end

function State:get_actions()
    return self.actions
end

function State:save_options()
    for opt, _ in pairs(self.options_to_restore) do
        if self.options_to_restore[opt].original == nil then
            self.options_to_restore[opt].original = vim.opt[opt]:get()
        end
    end
end

---Sets options to either original or new value
---@param conf "floating"|"original"|nil: defaults to original
function State:set_options(conf)
    for option, value in pairs(self.options_to_restore) do
        vim.opt[option] = value[conf] or value.original
    end
end

function State:create_autocmds()
    local augroup = vim.api.nvim_create_augroup("file-browser", { clear = true })

    vim.api.nvim_create_autocmd("WinLeave", {
        group = augroup,
        buffer = self.buffers.prompt,
        callback = function()
            self:set_options("original")
            self:close()
        end,
    })
    vim.api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        buffer = self.buffers.prompt,
        callback = function()
            self:set_options("floating")
        end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = augroup,
        buffer = self.buffers.results,
        callback = function()
            local line = vim.api.nvim_win_get_cursor(self.windows.results)[1]
            vim.api.nvim_win_set_cursor(self.windows.results_icon, { line, 0 })
        end,
    })

    vim.api.nvim_create_autocmd("TextChangedI", {
        group = augroup,
        buffer = self.buffers.prompt,
        callback = function()
            self:filter_results()
        end,
    })
end

--- Saves options, and then IF the windows are not valid, then create them
function State:create_windows()
    last_win = vim.api.nvim_get_current_win()

    self:save_options()

    self.win_configs, self.results_width = utils.get_win_configs(self.width_scale, self.height_scale, self.preview_width)
    self.buf_opts, self.win_opts = utils.get_opts()

    self:windo(function(kind, value)
        if not vim.api.nvim_buf_is_valid(self.buffers[kind]) then
            self.buffers[kind] = vim.api.nvim_create_buf(false, true)
        end

        if not vim.api.nvim_win_is_valid(value) then
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

    self:create_autocmds()
    self:_parse_mapping()

    self:create_mappings()
end

function State:reset_display_entries()
    self.display_entries = vim.deepcopy(self.entries)
    self.display_entries_nr = self.entries_nr
end

--- Get index of entry in the `entries` table
---@param value string: The text to search
---@return number index of entry in `entries`. -1 if not found
function State:index(value)
    for i, e in ipairs(self.entries) do
        if e.text == value then
            return i
        end
    end
    return -1
end

--- Gets the index in display value
---@param value string
---@return integer
function State:index_display(value)
    for i, e in ipairs(self.display_entries) do
        if e.text == value then
            return i
        end
    end
    return -1
end

function State:filter_results()
    local text = vim.api.nvim_buf_get_lines(self.buffers.prompt, 0, 1, false)[1]
    if text == nil or text == "" then
        self:reset_display_entries()
    else
        local texts = vim.iter(self.entries)
            :map(function(entry)
                return entry.text
            end)
            :totable()

        local cmd = string.format("echo '%s' | fzf --filter='%s'", table.concat(texts, "\n"), text)
        local results = vim.split(io.popen(cmd, "r"):read("*a"), "\n")

        self.display_entries = {}
        vim.iter(results):each(function(t)
            local i = self:index(t)
            table.insert(self.display_entries, self.entries[i])
        end)
        self.display_entries_nr = #self.display_entries
    end

    self:show_entries()
end

--- Displays the current `display_entries`.
---@param should_jump boolean?: Whether it should jump to first result of the list. Defaults to true
function State:show_entries(should_jump)
    local entry
    vim.api.nvim_buf_set_lines(self.buffers.results, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(self.buffers.results_icon, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(self.buffers.padding, 0, -1, false, {})
    for row = 1, self.display_entries_nr do
        entry = self.display_entries[row]
        -- row-1, row so that we effectively overwrite empty line
        vim.api.nvim_buf_set_lines(self.buffers.results, row - 1, row, false, { entry.text })
        vim.api.nvim_buf_set_lines(self.buffers.results_icon, row - 1, row, false, { entry.icon.text })
        vim.api.nvim_buf_set_lines(self.buffers.padding, row - 1, row, false, { "  " })
        set_hl(self.buffers.results_icon, entry.icon.hl, row - 1)
        set_hl(self.buffers.results, entry.icon.hl, row - 1)
    end

    vim.iter(self.marked[self.cwd] or {}):each(function(e)
        local idx = self:index_display(e.text)
        if idx ~= -1 then
            vim.api.nvim_buf_set_lines(self.buffers.padding, idx - 1, idx, false, { self.marked_icons.text })
            set_hl(self.buffers.padding, self.marked_icons.hl, idx - 1)
        end
    end)

    if should_jump == nil or should_jump then
        self.actions:jump_to(1, true) -- reset current entry to first, usually you want the first result when you search stuff
    end
end

--- Goes to a given directory, populating results and updating the state.
---@param cwd string: The path to cd to
---@param start_insert boolean?: Whether we should start in insert mode. Defaults to true
---@param relative boolean?: is it relative? defaults to false
function State:cd(cwd, start_insert, relative)
    self:reset_entries()
    if start_insert == nil or start_insert then
        vim.cmd([[startinsert]])
    end

    if cwd:sub(#cwd) ~= "/" then
        cwd = cwd .. "/"
    end

    if relative then
        self:update_prompt(self.cwd .. cwd, dir_hl)
    else
        self:update_prompt(cwd, dir_hl)
    end

    self.marked[self.cwd] = self.marked[self.cwd] or {}
    self:get_entries()

    self:show_entries()
end

--- Focuses the prompt window, creating windows if not valid
function State:focus()
    if not vim.api.nvim_win_is_valid(self.windows.prompt) then
        self:create_windows()
    end

    vim.api.nvim_set_current_win(self.windows.prompt)
end

---@type function|nil: it will be nil if no function was called in the last `self.debounce` ms, a function to cancel last invocation otherwise
local updating_preview = nil

function State:update_preview()
    if updating_preview ~= nil then
        updating_preview() -- cancel last invocation
    end

    updating_preview = defer(function() -- actual preview updating
        if vim.api.nvim_buf_is_valid(self.buffers.preview) then
            local curr = self.display_entries[self.display_current_entry_idx]
            if curr == nil then
                return
            end
            local fullpath = self.cwd .. curr.text
            if curr.is_dir then
                local tmp = {}
                self:_create_entries(fullpath, tmp)

                vim.api.nvim_buf_set_lines(self.buffers.preview, 0, -1, false, {})
                local entry
                for row = 1, #tmp do
                    entry = tmp[row]
                    -- row-1, row so that we effectively overwrite empty line
                    vim.api.nvim_buf_set_lines(self.buffers.preview, row - 1, row, false, { string.format("%s  %s", entry.icon.text, entry.text) })
                    vim.api.nvim_buf_add_highlight(self.buffers.preview, 0, entry.icon.hl, row - 1, 0, -1)
                end

                vim.bo[self.buffers.preview].filetype = ""
            else
                vim.api.nvim_buf_set_lines(self.buffers.preview, 0, -1, false, {})

                local ok, lines = pcall(vim.fn.readfile, fullpath)
                if not ok then
                    lines = {}
                end

                ok = pcall(vim.api.nvim_buf_set_lines, self.buffers.preview, 0, -1, false, lines)
                if not ok then
                    vim.api.nvim_buf_set_lines(self.buffers.preview, 0, -1, false, { "could not retreive preview" })
                end

                -- get ft without **setting** it. This prevents things from attaching, like lsp
                local ft = vim.filetype.match({ filename = curr.text }) or ""

                local highlighted = false
                if self.use_treesitter then
                    highlighted = pcall(vim.treesitter.start, self.buffers.preview, ft)
                end

                -- if either `use_treesitter = false` or no parser was found try to do with syntax
                if not highlighted then
                    vim.cmd.set("syntax=" .. ft)
                end
            end
        end
    end, self.debounce)
end

---Updates the prompt, prompt prefix and cwd
---@param cwd string: The path to show as a prefix
---@param prefix_hl string: the hl group to be assigned to the prompt prefix
function State:update_prompt(cwd, prefix_hl)
    local max_len = math.floor(self.win_configs.prompt.width * self.max_prompt_size)
    local prefix_len = #cwd
    local display_cwd = cwd
    if prefix_len > max_len then
        display_cwd = string.format("...%s", cwd:sub(prefix_len - max_len + 4))
        prefix_len = max_len
    end

    self.win_configs.prompt_prefix.width = prefix_len
    self.win_configs.prompt.col = self.win_configs.prompt_prefix.col + prefix_len + 1
    self.win_configs.prompt.width = self.results_width - (prefix_len + 1)
    vim.api.nvim_win_set_config(self.windows.prompt_prefix, self.win_configs.prompt_prefix)
    vim.api.nvim_win_set_config(self.windows.prompt, self.win_configs.prompt)

    vim.api.nvim_buf_set_lines(self.buffers.prompt_prefix, 0, -1, false, { display_cwd })
    vim.api.nvim_buf_add_highlight(self.buffers.prompt_prefix, 0, prefix_hl, 0, 0, -1)

    self:set_cwd(cwd)
end

--- Populates the state with the entries for the current directory. Note that this does not
--- display anything!
function State:get_entries()
    self:_create_entries(self.cwd)

    self.entries_nr = #self.entries
    self.current_entry = 1

    self.display_entries = vim.deepcopy(self.entries)
    self.display_entries_nr = self.entries_nr
end

---@private
--- Calls given function on every window in the state
---@param func fun(string, number):any
function State:windo(func)
    for kind, value in pairs(self.windows) do
        func(kind, value)
    end
end

--- Close all windows
function State:close()
    utils.normal_mode()
    self:windo(function(_, value)
        if vim.api.nvim_win_is_valid(value) then
            vim.api.nvim_win_close(value, true)
        end
    end)
    vim.api.nvim_set_current_win(last_win)
end

--- Empties the list of entries
function State:reset_entries()
    self.entries = {}
    self.entries_nr = 0
    self.current_entry = -1

    self.display_entries = {}
    self.display_entries_nr = 0
    self.display_current_entry_idx = -1
end

---@private
function State:set_cwd(cwd)
    self.cwd = cwd
end

State.__index = State
return State
