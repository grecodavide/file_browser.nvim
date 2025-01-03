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

local function is_insert()
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

---@private
--- Opens a file.
---@param file string
---@param absolute boolean?: defaults to true
function Actions:_open(file, absolute)
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
        self:_open(new_cwd, true)
    end
end

---@private
---Calls the `mv` command
---@param old string
---@param new string
---@param ask_override boolean?: Ask override? defaults to false. If false, will simply not move that file
---@return boolean: success?
local function move(old, new, ask_override)
    local base = utils.get_file_path(new)
    local cmd = string.format("[ ! -d %s ] && mkdir -p %s || exit 0 2>/dev/null", base, base)
    if os.execute(cmd) ~= 0 then
        utils.error("Could not create base directory after moving.")
        return false
    end

    cmd = string.format("([ -f %s ] && [ -f %s ]) || ([ -d %s ] && [ -d %s ])", old, new, old, new)
    if os.execute(cmd) then
        if ask_override then
            local confirmation = vim.fn.input({ prompt = string.format("%s already exists. Override? [y/N]", new), cancelreturn = "CANCEL" })
            if confirmation ~= nil and confirmation ~= "y" then
                utils.log("Move canceled.")
                return false
            end
        else
            utils.log("Could not move " .. old .. " to " .. new .. ": already exists.")
            return false
        end
    end

    local exit_code = os.execute(string.format("mv %s %s 2>/dev/null", old, new))
    if exit_code ~= 0 then
        utils.error("Could not move " .. old .. " to " .. new)
        return false
    end
    return true
end

--- Moves selection to cwd
---@param delete_selection boolean?: Remove marks after a successful move? defaults to true
function Actions:move_to_cwd(delete_selection)
    local new_marked = {}
    local was_selected = self.state:get_current_entry()

    vim.iter(self.state.marked):each(function(cwd, entries)
        for _, entry in ipairs(entries) do
            local fullpath = string.format("%s%s", cwd, entry.text)
            if move(fullpath, self.state.cwd) then
                if delete_selection ~= nil and not delete_selection then
                    if new_marked[self.state.cwd] == nil then
                        new_marked[self.state.cwd] = {}
                    end
                    table.insert(new_marked[self.state.cwd], entry)
                end
            end
        end
    end)

    if new_marked[self.state.cwd] == nil then
        new_marked[self.state.cwd] = {}
    end

    self.state.marked = new_marked
    self.state:reload()
    self:jump_to(self.state:index_display(was_selected.text), true)
end

--- Moves selection to cwd
---@param delete_selection boolean?: Remove marks after a successful move? defaults to true
function Actions:copy_to_cwd(delete_selection)
    vim.iter(self.state.marked):each(function(cwd, entries)
        for i, entry in ipairs(entries) do
            local fullpath = string.format("%s%s", cwd, entry.text)
            local exit_code = os.execute(string.format("cp -r %s %s >/dev/null", fullpath, self.state.cwd))
            if exit_code ~= 0 then
                utils.error("Could not copy " .. entry.text)
            else
                if delete_selection == nil or delete_selection then
                    table.remove(self.state.marked[self.state.cwd], i)
                end
            end
        end
    end)
    local old = self.state.display_current_entry_idx

    self.state:reload()
    self:jump_to(old, true)
end

--- Sets nvim CWD to the one of this plugin
function Actions:cd()
    vim.cmd.cd(self.state.cwd)
    print("Set CWD to " .. self.state.cwd)
end

---@private
--- Searches the current entry among the marked ones, returning its index if found, -1 otherwise
---@return number: The searched index, or -1 if not found
function Actions:search_marked()
    local current_entry = self.state:get_current_entry()
    for i, k in ipairs(self.state.marked[self.state.cwd]) do
        if k.text == current_entry.text then
            return i
        end
    end

    return -1
end

--- Renames current entry
function Actions:rename()
    local entry = self.state:get_current_entry()
    local old_name = entry.text
    if entry.is_dir then
        old_name = string.sub(old_name, 1, #old_name - 1)
    end
    local new_name = vim.fn.input({ prompt = "New name: ", default = old_name, cancelreturn = "CANCEL" })
    -- local new_name = vim.fn.input("New name: ")
    if new_name == nil or new_name == "CANCEL" then
        return
    end

    local cmd = string.format("cd %s && [ ! -f %s ] && [ ! -d %s ]", self.state.cwd, new_name, new_name)

    local exists = os.execute(cmd) ~= 0

    if exists then
        utils.error("Cannot rename: file/dir with that name already exists")
        return
    end

    if os.execute(string.format("cd %s && mv %s %s", self.state.cwd, old_name, new_name)) ~= 0 then
        utils.error("Error while trying to rename.")
        return
    end

    self.state:reload()
end

---Bulk rename selection
---@param ask_override boolean?: ask override in case file already exists. Default to false, and won't move file in that case
---@param delete_selection boolean?: should delete selection after renaming. Defaults to true
function Actions:bulk_rename(ask_override, delete_selection)
    local old = self.state:get_current_entry()
    local insert = is_insert()
    local last_win = self.state.last_win -- save actual last win

    local buf = vim.api.nvim_create_buf(false, true)
    utils.normal_mode()
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = self.state.win_configs.prompt_prefix.row,
        col = self.state.win_configs.prompt_prefix.col,
        width = math.floor(self.state.width_scale * vim.o.columns),
        height = math.floor(self.state.height_scale * vim.o.lines),
        title = "Bulk Rename",
        border = "single",
        zindex = 200, -- above everything
    })
    local entries = {}
    for path, values in pairs(self.state.marked) do
        for _, entry in pairs(values) do
            table.insert(entries, table.concat({ path, entry.text }))
        end
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, entries)
    local new_marked = {}

    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = buf,
        callback = function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            if #lines == 1 and lines[1] ~= "" or #lines > 1 then
                for linenr, line in pairs(lines) do
                    local old_line = entries[linenr]
                    if old_line ~= line then
                        if move(old_line, line, ask_override) then
                            if delete_selection ~= nil and not delete_selection then
                                local base = utils.get_file_path(line)
                                local file = line:match("[^/]+$")
                                if new_marked[base] == nil then
                                    new_marked[base] = {}
                                end
                                table.insert(new_marked[base], file)
                            end
                        end
                    else
                        utils.log("Not moving " .. old_line .. ": destination equal to source")
                    end
                end
                if new_marked[self.state.cwd] == nil then
                    new_marked[self.state.cwd] = {}
                end
                self.state.marked = new_marked
            end

            self.state:focus()
            self.state:cd(self.state.cwd, insert)
            self:jump_to(self.state:entry_index(old.text), true)
            self.state.last_win = last_win
        end,
    })
end

--- Marks current entry.
function Actions:mark_current()
    local idx = self:search_marked()
    local text
    if idx == -1 then
        table.insert(self.state.marked[self.state.cwd], self.state:get_current_entry())
        text = { table.concat({ self.state.marked_icon.text, " " }) }
    else
        table.remove(self.state.marked[self.state.cwd], idx)
        text = { "" } -- empty line, not nothing: it would delete the line and so move all the other marks
    end

    vim.api.nvim_buf_set_lines(
        self.state.buffers.padding,
        self.state.display_current_entry_idx - 1, -- 0 indexed
        self.state.display_current_entry_idx,
        false,
        text
    )
    utils.set_hl(self.state.buffers.padding, self.state.marked_icon.hl, self.state.display_current_entry_idx - 1)

    vim.api.nvim_win_set_cursor(self.state.windows.padding, { self.state.display_current_entry_idx, 0 })
end

--- Deletes a file/folder.
---@param force boolean?: Whether the command should be forced. Defaults to false
---@param ask_confirmation boolean?: Whether the command should ask for confirmation before deleting. Defaults to true
function Actions:delete(force, ask_confirmation)
    local entry = table.concat({ self.state.cwd, self.state:get_current_entry().text })
    local cmd = string.format("rm --interactive=never -r%s >/dev/null", force and "f" or "")

    if ask_confirmation ~= false then
        local confirmation = vim.fn.input({ prompt = "Confirm? [Y/n] ", cancelreturn = "CANCEL" })
        if confirmation == nil or confirmation == "CANCEL" or confirmation == "n" then
            utils.log("Deletion canceled")
            return
        end
    end

    local exit_code = os.execute(table.concat({ cmd, entry }, " "))
    if exit_code ~= 0 then
        utils.error("Could not delete!")
    end
    self.state:reload()
end

--- Closes windows
function Actions:close()
    self.state:close()
end

--- Creates file/directory.
---@param jump boolean?: Should jump to created directory/open file? Defaults to true
function Actions:create(jump)
    local cwd = self.state.cwd
    local input = vim.fn.input("Create: ")
    local base = input:match("(.+)/.*") or ""
    local file = input:match("[^/]+$")
    local first = table.concat({ self.state.cwd, input:match("^[^/]+") })

    if base ~= "" then
        base = table.concat({ self.state.cwd, base })
        if os.execute(string.format("[ ! -f %s ] && mkdir -p %s || exit 1", first, base)) ~= 0 then
            utils.error("Could note create directories.")
            return
        end

        if jump == nil or jump then
            self.state:cd(base, is_insert())
        end
    end

    if file ~= nil then
        file = table.concat({ cwd, input })
        if os.execute(string.format("[ ! -f %s ] && touch %s", file, file)) ~= 0 then
            utils.error("Could note create file.")
            return
        end
        if jump == nil or jump then
            self:_open(file, true)
            return
        end
    end

    self.state:reload()
end

--- Goes to parent directory
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

--- If prompt is empty, goes to parent mode, otherwise behave like a regular <BS>.
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

    -- if there are no entries, don't try to move the cursor
    if self.state.display_entries_nr > 0 then
        vim.api.nvim_win_set_cursor(self.state.windows.results, { self.state.display_current_entry_idx, 0 })
        vim.api.nvim_win_set_cursor(self.state.windows.padding, { self.state.display_current_entry_idx, 0 })
        vim.api.nvim_win_set_cursor(self.state.windows.results_icon, { self.state.display_current_entry_idx, 0 })
    end

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
