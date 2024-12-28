-- TODO:
-- Actions to implement:
-- - cd (with ./<C-.>)
-- - create new file/dir
-- - move file/dir
-- - delete file/dir
-- - oil like shit
-- Possible option: autocmd on text yank that saves the chosen entry/ies, and if deleted remove from display list
-- Things to do:
-- - add option to determine percentage of prompt before trimming it: for example we can
--   add option to opts defining the percentage, and on update_prompt do a check: if len > max_len ( = winconf.prompt.width * percentage)
--   then print only the last max_len chars

--- Create cmd to get all entries matching a certain type in the given directory, and get its output
---@param path string: The path to search into
---@param type "f"|"d"|"l"|"a": The type to match.
---@param show_hidden boolean: Whether to show hidden files
---@return string[]: The output for this command
local function get_cmd(path, type, show_hidden)
    print(path)
    if show_hidden then
        if type == "a" then
            return vim.split(io.popen(string.format("cd '%s' && fd --hidden --exact-depth=1", path), "r"):read("*a"), "\n")
        end
        return vim.split(io.popen(string.format("cd '%s' && fd --hidden --exact-depth=1 -t %s", path, type), "r"):read("*a"), "\n")
    end

    if type == "a" then
        return vim.split(io.popen(string.format("cd '%s' && fd --exact-depth=1", path), "r"):read("*a"), "\n")
    end
    return vim.split(io.popen(string.format("cd '%s' && fd --exact-depth=1 -t %s", path, type), "r"):read("*a"), "\n")
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
        is_dir = false,
        marked = false,
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

local create_entries = function(cwd, display_links, show_hidden, tbl)
    local directories = get_cmd(cwd, "d", show_hidden)
    for _, dir in pairs(directories) do
        if dir and dir ~= "" then
            table.insert(tbl, {
                icon = {
                    text = dir_icon_text,
                    hl = dir_hl,
                },
                text = dir,
                is_dir = true,
                marked = false,
            })
        end
    end

    if display_links then
        local links = get_cmd(cwd, "l", show_hidden)
        for _, link in pairs(links) do
            if link and link ~= "" then
                table.insert(tbl, {
                    icon = {
                        text = link_icon_text,
                        hl = link_icon_hl,
                    },
                    text = link,
                    is_dir = false,
                    marked = false,
                })
            end
        end
    end

    local files = get_cmd(cwd, "f", show_hidden)
    for _, file in pairs(files) do
        if file and file ~= "" then
            table.insert(tbl, transform(file))
        end
    end
end

-- TODO: state should also contain a "marked" value, containing all file
-- marked for either selection or cut

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
---@field cwd string
---@field show_hidden boolean
---@field width_scale number
---@field height_scale number
---@field preview_width number
---@field max_prompt_size number
---@field marked_icons file_browser.MarkIcons
---@field marked {selected: file_browser.Entry[], cut: file_browser.Entry[]}
---@field debounce number
---@field display_links boolean
local State = {}

local actions

---Returns a default state
---@return file_browser.State
function State:new(debounce, display_links, show_hidden, width_scale, height_scale, preview_width, max_prompt_size, marked_icons)
    marked_icons = {
        selected = {
            text = string.format(" %s", marked_icons.selected.text),
            hl = marked_icons.selected.hl,
        },
        cut = {
            text = string.format(" %s", marked_icons.selected.text),
            hl = marked_icons.selected.hl,
        },
    }

    return setmetatable({
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
        display_current_entry = -1,
        display_entries_nr = 0,

        width_scale = width_scale,
        height_scale = height_scale,
        preview_width = preview_width,
        max_prompt_size = max_prompt_size,

        marked_icons = marked_icons,

        show_hidden = show_hidden,

        debounce = debounce,
        display_links = display_links,
    }, self)
end

function State:get_prompt()
    return vim.api.nvim_buf_get_lines(self.buffers.prompt, 0, -1, false)[1]
end

function State:create_mappings()
    -- #############
    -- ### CLOSE ###
    -- #############
    map("n", "<Esc>", function()
        self:close()
    end, self.buffers.prompt)

    -- ######################
    -- ### HANDLE PREVIEW ###
    -- ######################
    map({ "i", "n" }, "<C-d>", function()
        vim.api.nvim_win_set_cursor(self.windows.preview, { math.min(vim.fn.line("w$", self.windows.preview) + 1, vim.fn.line("$", self.windows.preview)), 0 })
    end, { self.buffers.prompt, self.buffers.results })
    map({ "i", "n" }, "<C-u>", function()
        vim.api.nvim_win_set_cursor(self.windows.preview, { math.max(vim.fn.line("w0", self.windows.preview) - 1, 1), 0 })
    end, { self.buffers.prompt, self.buffers.results })

    -- ####################
    -- ### GOTO RESULTS ###
    -- ####################
    map("i", "<C-f>", function()
        utils.normal_mode()
        vim.api.nvim_set_current_win(self.windows.results)
    end, self.buffers.prompt)
    map({ "n" }, "e", function()
        vim.api.nvim_set_current_win(self.windows.results)
    end, self.buffers.prompt)

    -- ###############
    -- ### MARKING ###
    -- ###############
    map("i", "<C-s>", function()
        self.display_entries[self.display_current_entry_nr].marked = not self.display_entries[self.display_current_entry_nr].marked
        self:show_entries()
    end, self.buffers.prompt)

    -- ########################
    -- ### RESULTS HANDLING ###
    -- ########################
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
    map({ "n", "i" }, "<C-v>", function()
        self:open_vsplit()
    end, { self.buffers.prompt, self.buffers.results })
    map({ "n", "i" }, "<S-CR>", function()
        self:default_action(true)
    end, { self.buffers.prompt, self.buffers.results })

    -- ##############
    -- ### PROMPT ###
    -- ##############
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
        end,
    })
    vim.api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        buffer = self.buffers.results,
        callback = function()
            self:set_options("floating")
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
        if entry.marked then
            vim.api.nvim_buf_set_lines(self.buffers.padding, row - 1, row, false, { self.marked_icons.selected.text })
            vim.api.nvim_buf_add_highlight(self.buffers.padding, 0, self.marked_icons.selected.hl, row - 1, 0, -1)
        else
            vim.api.nvim_buf_set_lines(self.buffers.padding, row - 1, row, false, { "  " })
        end
        vim.api.nvim_buf_add_highlight(self.buffers.results_icon, 0, entry.icon.hl, row - 1, 0, -1)
        vim.api.nvim_buf_add_highlight(self.buffers.results, 0, entry.icon.hl, row - 1, 0, -1)
    end

    -- if self.display_current_entry == -1 then
    self:jump(1, true) -- reset current entry to first, usually you want the first result when you search stuff
    -- end
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
function State:get_selected()
    vim.print(marked)
end

function State:get_selected_cut()
    return vim.iter(self.entries)
        :filter(function(entry)
            return entry.marked_cut
        end)
        :totable()
end

function State:update_preview()
    local curr = self.display_entries[self.display_current_entry_idx]
    if curr == nil then
        return
    end
    local fullpath = self.cwd .. curr.text
    if curr.is_dir then
        local tmp = {}
        create_entries(fullpath, self.display_links, self.show_hidden, tmp)

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
        vim.api.nvim_set_current_win(self.windows.preview)
        vim.cmd(string.format("silent read %s", fullpath))
        vim.api.nvim_buf_set_lines(self.buffers.preview, 0, 1, false, {}) -- remove first line, as read on empty buf will always leave the first line empty
        local ft = vim.filetype.match({ filename = curr.text }) or ""
        vim.cmd.set("syntax=" .. ft)
        -- vim.bo[self.buffers.preview].filetype = vim.filetype.match({ filename = curr.text }) or ""
        vim.api.nvim_set_current_win(self.windows.prompt)
    end
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

---Populates the state with the entries for the current directory
function State:get_entries()
    create_entries(self.cwd, self.display_links, self.show_hidden, self.entries)

    self.entries_nr = #self.entries
    self.current_entry = 1

    self.display_entries = vim.deepcopy(self.entries)
    self.display_entries_nr = self.entries_nr
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
    local new_cwd = self.cwd .. self.display_entries[self.display_current_entry_nr].text
    if self.display_entries[self.display_current_entry_nr].is_dir then
        if cd then
            vim.fn.chdir(new_cwd)
        end
        self:cd(new_cwd, is_insert())

        -- reset prompt
        vim.api.nvim_buf_set_lines(self.buffers.prompt, 0, -1, false, {})
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

--- Close all windows
function State:close()
    self:windo(function(_, value)
        vim.api.nvim_win_close(value, true)
    end)
end

--- Opens in vsplit if current entry is file
function State:open_vsplit()
    local new_cwd = self.cwd .. self.display_entries[self.display_current_entry_nr].text
    if self.display_entries[self.display_current_entry_nr].is_dir then
        return
    end

    utils.normal_mode()
    self:close()

    vim.cmd.vsplit(new_cwd)
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
