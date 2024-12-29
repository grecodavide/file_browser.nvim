-- TODO:
-- Actions to implement:
-- - cd (with ./<C-.>)
-- - create new file/dir
-- - move file/dir
-- - delete file/dir
-- - oil like shit
-- Possible option: autocmd on text yank that saves the chosen entry/ies, and if deleted remove from display list
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
        self.state:close()

        if cd then
            vim.fn.chdir(self.state.cwd)
        end
        vim.cmd.edit(new_cwd)
    end
end

--- Sets nvim CWD to the one of this plugin
function Actions:cd()
    vim.cmd.cd(self.state.cwd)
end

--- Deletes a file/folder.
---@param force boolean?: Whether the command should be forced. Defaults to false
---@param ask_confirmation boolean?: Whether the command should ask for confirmation before deleting. Defaults to true
function Actions:delete(force, ask_confirmation)
    local entry = table.concat({ self.state.cwd, self.state:get_current_entry().text })
    local cmd = string.format("rm -r%s", force and "f" or "")

    if ask_confirmation == false or vim.fn.input("Confirm? [Y/n] ") ~= "n" then
        os.execute(table.concat({ cmd, entry }, " "))
    end

    self.state:cd(self.state.cwd, is_insert())
end

--- Creates file/directory.
function Actions:create()
    local input = vim.fn.input("Create: ")
    local base = input:match("(.+)/.*") or ""
    local file = input:match("[^/]+$")
    local first = table.concat({ self.state.cwd, input:match("^[^/]+") })

    if base ~= "" then
        base = table.concat({ self.state.cwd, base })
        if os.execute(string.format("[ ! -f %s ] && mkdir -p %s || exit 1", first, base)) ~= 0 then
            vim.notify("Could note create directories.", vim.log.levels.WARN, {})
            return
        end
    end

    if file ~= nil then
        file = table.concat({ self.state.cwd, input })
        if os.execute(string.format("[ ! -f %s ] && touch %s", file, file)) ~= 0 then
            vim.notify("Could note create file.", vim.log.levels.WARN, {})
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

        self:jump(self.state:index_display(curr), true)
    end
end

---Jumps to a given entry in the list, by specifying an index
---@param index number: the index to jump to (relative or absolute)
---@param absolute boolean?: Whether the given index is absolute. Defaults to false
function Actions:jump(index, absolute)
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
