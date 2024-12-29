local M = {}

---Gets all the options for the windows
---@return table<string, vim.bo>, table<string, vim.wo>: A table containing, for each window, all buffer and windows options
M.get_opts = function()
    return {
        prompt_prefix = {
            bufhidden = "wipe",
        },
        prompt = {
            bufhidden = "wipe",
        },
        results = {
            bufhidden = "wipe",
        },
        results_icon = {
            bufhidden = "wipe",
        },
        preview = {
            bufhidden = "wipe",
        },
        padding = {
            bufhidden = "wipe",
        },
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
            number = false,
            relativenumber = false,
        },

        padding = {
            cursorline = true,
            number = false,
            relativenumber = false,
            signcolumn = "no",
        },
    }
end

M.normal_mode = function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "i", false)
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
    local base_row = bit.rshift(math.ceil(height * (1 - height_scale)), 1)
    local base_col = bit.rshift(math.ceil(width * (1 - width_scale)), 1)

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
            width = 3,
            height = results_height,
            row = base_row + 3,
            col = base_col,
            border = { "│", " ", " ", "", "─", "─", "└", "│" },
            zindex = 100,
            focusable = false,
        },
        results_icon = {
            relative = "editor",
            width = 2,
            height = results_height,
            row = base_row + 3,
            col = base_col + 3,
            border = { " ", " ", " ", "", " ", "─", "─", " " },
            zindex = 2,
            focusable = false,
        },
        results = {
            relative = "editor",
            width = results_width - 6, -- padding (1), results_icon (2), two double borders (2 each)
            height = results_height,
            row = base_row + 3,
            col = base_col + 6,
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

--- Defers the call of a function, returning a handle to cancel that invocation
---@param func function: the function o be deferred
---@param delay number: ms to wait before invoking the function
---@return function: handle to cancel last invocation
M.defer = function(func, delay)
    local timer = vim.uv.new_timer()
    -- Start the timer
    timer:start(delay, 0, function()
        vim.schedule(func) -- Schedule the function on Neovim's main thread
        timer:stop()
        timer:close()
    end)

    return function()
        if not timer:is_closing() then
            timer:stop()
            timer:close()
        end
    end
end

return M
