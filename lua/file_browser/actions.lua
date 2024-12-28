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
        self.state:windo(function(_, value)
            vim.api.nvim_win_close(value, true)
        end)

        utils.normal_mode()
        if cd then
            vim.fn.chdir(self.state.cwd)
        end
        vim.cmd.edit(new_cwd)
    end
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

-- init as nil: never called
local update_preview = nil

-- this function does handles the debounce: basically
local function defer_with_cancel(func, delay)
    local timer = vim.loop.new_timer()

    -- Start the timer
    timer:start(delay, 0, function()
        vim.schedule(func) -- Schedule the function on Neovim's main thread
        timer:stop()
        timer:close()
    end)

    -- Return a cancel function: if we call the return value of this function,
    -- we will stop the execution of the given function (as long as the time did not elapse)
    return function()
        if not timer:is_closing() then
            timer:stop()
            timer:close()
        end
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

    -- if update_preview is not nil we already called the function in the last `self.state.debounce` ms!
    -- so we need to cancel that call
    if update_preview ~= nil then
        update_preview()
    end

    -- Defer the update of preview window
    update_preview = defer_with_cancel(function()
        if vim.api.nvim_buf_is_valid(self.state.buffers.preview) then
            self.state:update_preview()
        end
        update_preview = nil
    end, self.state.debounce)
end

--- Opens in vsplit if current entry is file
function Actions:open_vsplit()
    local new_cwd = self.state.cwd .. self.state.display_entries[self.state.display_current_entry_idx].text
    if self.state.display_entries[self.state.display_current_entry_idx].is_dir then
        return
    end

    utils.normal_mode()
    self.state:close()

    vim.cmd.vsplit(new_cwd)
end

Actions.__index = Actions
return Actions
