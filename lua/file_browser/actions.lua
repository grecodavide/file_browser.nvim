-- TODO:
-- Actions to implement:
-- - move file/dir
-- - rename file
local utils = require("file_browser.utils")

---@class file_browser.Actions
---@field state file_browser.State
local Actions = {}

--- Binds actions to state
---@param state file_browser.State
---@return file_browser.Actions
function Actions:new(state)
    return setmetatable({
        state = state,
    }, self)
end

local is_insert = function()
    return vim.fn.mode() == "i"
end

--- Scrolls preview window up, if possible
function Actions:scroll_preview_up()
    vim.api.nvim_win_set_cursor(self.state.windows.preview, { math.max(vim.fn.line("w0", self.state.windows.preview) - 1, 1), 0 })
end

--- Scrolls preview window down, if possible
function Actions:scroll_preview_down()
    vim.api.nvim_win_set_cursor(
        self.state.windows.preview,
        { math.min(vim.fn.line("w$", self.state.windows.preview) + 1, vim.fn.line("$", self.state.windows.preview)), 0 }
    )
end

--- Opens a file.
---@param file string
---@param absolute boolean?: defaults to true
function Actions:open(file, absolute)
    self.state:close()

    if absolute == nil or absolute then
        vim.cmd.edit(file)
    else
        vim.cmd.edit(self.state.cwd .. file)
    end
end

--- Default action. If dir, sets state.cwd to it, if file, opens it
---@param cd boolean?: should cd to directory. Defaults to false
function Actions:default(cd)
    local entry = self.state.display_entries[self.state.display_current_entry_idx]
    local new_cwd
    if entry == nil then
        new_cwd = table.concat({ self.state.cwd, self.state:get_prompt() })
    else
        new_cwd = table.concat({ self.state.cwd, entry.text })
    end

    if entry and entry.is_dir then
        if cd then
            vim.fn.chdir(new_cwd)
        end
        self.state:cd(new_cwd, is_insert())

        -- reset prompt
        vim.api.nvim_buf_set_lines(self.state.buffers.prompt, 0, -1, false, {})
    else
        if cd then
            vim.fn.chdir(self.state.cwd)
        end
        self:open(new_cwd, true)
    end
end

function Actions:move_to_cwd()
    vim.iter(self.state.marked):each(function(entry)
        vim.print(entry)
    end)
end

--- Sets nvim CWD to the one of this plugin
function Actions:cd()
    vim.cmd.cd(self.state.cwd)
    print("Set CWD to " .. self.state.cwd)
end

--- Searches the current entry among the marked ones, returning its index if found, -1 otherwise
---@return number: The searched index, or -1 if not found
function Actions:search_marked()
    for i, k in ipairs(self.state.marked) do
        if k.text == self.state:get_current_entry().text then
            return i
        end
    end

    return -1
end

function Actions:rename()
    local entry = self.state:get_current_entry()
    local old_name = entry.text
    if entry.is_dir then
        old_name = string.sub(old_name, 1, #old_name - 1)
    end
    local new_name = vim.fn.input("New name: ")
    if new_name == nil or new_name == "" then
        return
    end

    local cmd = string.format("cd %s && [ ! -f %s ] && [ ! -d %s ]", self.state.cwd, new_name, new_name)

    local exists = os.execute(cmd) ~= 0

    if exists then
        vim.notify("Cannot rename: file/dir with that name already exists", vim.log.levels.ERROR, {})
        return
    end

    if os.execute(string.format("cd %s && mv %s %s", self.state.cwd, old_name, new_name)) ~= 0 then
        vim.notify("Error while trying to rename.", vim.log.levels.ERROR, {})
        return
    end

    self.state:cd(self.state.cwd, is_insert())
end

function Actions:mark_current()
    local idx = self:search_marked()
    local text
    if idx == -1 then
        table.insert(self.state.marked, self.state:get_current_entry())
        text = { table.concat({ self.state.marked_icons.selected.text, " " }) }
    else
        table.remove(self.state.marked, idx)
        text = { "" } -- empty line, not nothing: it would delete the line and so move all the other marks
    end

    vim.api.nvim_buf_set_lines(
        self.state.buffers.padding,
        self.state.display_current_entry_idx - 1, -- 0 indexed
        self.state.display_current_entry_idx,
        false,
        text
    )
    utils.set_hl(self.state.buffers.padding, self.state.marked_icons.selected.hl, self.state.display_current_entry_idx - 1)

    vim.api.nvim_win_set_cursor(self.state.windows.padding, { self.state.display_current_entry_idx, 0 })
end

--- Deletes a file/folder.
---@param force boolean?: Whether the command should be forced. Defaults to false
---@param ask_confirmation boolean?: Whether the command should ask for confirmation before deleting. Defaults to true
function Actions:delete(force, ask_confirmation)
    local entry = table.concat({ self.state.cwd, self.state:get_current_entry().text })
    local cmd = string.format("rm --interactive=never -r%s", force and "f" or "")

    if ask_confirmation == false or vim.fn.input("Confirm? [Y/n] ") ~= "n" then
        local exit_code = os.execute(table.concat({ cmd, entry }, " "))
        if exit_code ~= 0 then
            vim.notify("Could not delete!", vim.log.levels.ERROR, {})
        end
    end

    self.state:cd(self.state.cwd, is_insert())
end

--- Closes windows
function Actions:close()
    self.state:close()
end

--- Creates file/directory.
---@param jump boolean?: Should jump to created directory/open file?
function Actions:create(jump)
    local cwd = self.state.cwd
    local input = vim.fn.input("Create: ")
    local base = input:match("(.+)/.*") or ""
    local file = input:match("[^/]+$")
    local first = table.concat({ self.state.cwd, input:match("^[^/]+") })

    if base ~= "" then
        base = table.concat({ self.state.cwd, base })
        if os.execute(string.format("[ ! -f %s ] && mkdir -p %s || exit 1", first, base)) ~= 0 then
            vim.notify("Could note create directories.", vim.log.levels.ERROR, {})
            return
        end

        if jump == nil or jump then
            self.state:cd(base, is_insert())
        end
    end

    if file ~= nil then
        file = table.concat({ cwd, input })
        if os.execute(string.format("[ ! -f %s ] && touch %s", file, file)) ~= 0 then
            vim.notify("Could note create file.", vim.log.levels.ERROR, {})
            return
        end
        if jump == nil or jump then
            self:open(file, true)
            return
        end
    end

    self.state:cd(self.state.cwd, is_insert())
end

---Go to parent directory
---@param start_insert boolean?
function Actions:goto_parent(start_insert)
    local _, seps = self.state.cwd:gsub("/", "")
    if seps > 0 then
        local cwd = select(1, self.state.cwd:gsub("(.*)/.+$", "%1/"))
        local curr = select(1, self.state.cwd:gsub(".*/(.+)/.*$", "%1/"))
        self.state:cd(cwd, start_insert)

        self:jump_to(self.state:index_display(curr), true)
    end
end

function Actions:goto_parent_or_delete()
    if self.state:get_prompt() == "" then
        self:goto_parent(is_insert())
    else
        -- mode = 'n' means "ignore remappings, behave regularly"
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", false)
    end
end

---Jumps to a given entry in the list, by specifying an index
---@param index number: the index to jump to (relative or absolute)
---@param absolute boolean?: Whether the given index is absolute. Defaults to false
function Actions:jump_to(index, absolute)
    local new_curr

    if absolute then
        new_curr = index
    else
        new_curr = self.state.display_current_entry_idx + index
    end

    if new_curr <= 0 then
        new_curr = self.state.display_entries_nr
    elseif new_curr > self.state.display_entries_nr then
        new_curr = 1
    end

    self.state.display_current_entry_idx = new_curr

    vim.api.nvim_win_set_cursor(self.state.windows.results, { self.state.display_current_entry_idx, 0 })
    vim.api.nvim_win_set_cursor(self.state.windows.padding, { self.state.display_current_entry_idx, 0 })
    vim.api.nvim_win_set_cursor(self.state.windows.results_icon, { self.state.display_current_entry_idx, 0 })

    self.state:update_preview()
end

--- Opens in vsplit if current entry is file
---@param vertical boolean?: is it vsplit? default is true
function Actions:open_split(vertical)
    local new_cwd = self.state.cwd .. self.state.display_entries[self.state.display_current_entry_idx].text
    if self.state.display_entries[self.state.display_current_entry_idx].is_dir then
        return
    end

    utils.normal_mode()
    self.state:close()

    if vertical == nil or vertical then
        vim.cmd.vsplit(new_cwd)
    else
        vim.cmd.split(new_cwd)
    end
end

Actions.__index = Actions
return Actions
