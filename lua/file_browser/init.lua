local M = {}
local mini_icons = require("mini.icons")

---@class file_browser.Entry
---@field text string: text
---@field icon string: icon

---@class file_browser.Layout
---@field prompt integer
---@field results integer
---@field preview integer

---@class file_browser.State
---@field windows file_browser.Layout: the Windows ID (initialized at invalid values)
---@field buffers file_browser.Layout: the Buffers ID (initialized at invalid values)
---@field entries table<string, file_browser.Entry[]>: the Buffers ID (initialized at invalid values)
local state = {
    windows = {
        prompt = -1,
        results_icon = -1,
        results = -1,
        preview = -1,
    },

    buffers = {
        prompt = -1,
        results_icon = -1,
        results = -1,
        preview = -1,
    },

    entries = {
        files = {},
        directories = {},
        links = {},
    },
}

---@class file_browser.Config
---@field start_insert boolean: Wether we should start in insert mode
---@field cwd string?: Directory under which we should search
---@field display_symlinks boolean: Wehter we should show symlinks or not
M.opts = {
    start_insert = true,
    display_symlinks = true,
}

M.options = {
    fillchars = {
        floating = { eob = " " },
        original = {},
    },
}

local function get_cmd(path, type)
    return vim.split(io.popen(string.format("cd %s && fd --exact-depth=1 -t %s", path, type), "r"):read("*a"), "\n")
end

---Transforms text to entry
---@param entry string
---@return file_browser.Entry
local function transform(entry)
    return {
        icon = mini_icons.get("file", entry),
        text = entry,
    }
end

local function get_entries(cwd)
    -- state.entries.files = vim.iter(get_cmd(cwd, "f")):map(transform)
    state.entries.directories = vim.iter(get_cmd(cwd, "d"))
        :filter(function(entry)
            return entry ~= nil and entry ~= ""
        end)
        :map(transform)
        :totable()
end

local save_options = function()
    M.options.fillchars.original = vim.opt.fillchars
    -- M.options.fillchars.original = vim.opt.fillchars
end

---Sets options to either original or new value
---@param conf string
local set_options = function(conf)
    for option, value in pairs(M.options) do
        vim.opt[option] = value[conf] or value.original
    end
end

---Gets the windows configuration, used to create such windows
---@return table: The config for prompt, results and preview window
local get_win_configs = function()
    local width = vim.o.columns
    local half_width = bit.rshift(width, 1) - 2 -- remove 2 for padding

    local prompt_row = 1
    local prompt_height = 1

    local results_height = vim.o.lines - prompt_row - prompt_height - 4
    local icon_size = 2

    ---@type table<string, vim.api.keyset.win_config>
    return {
        prompt = {
            relative = "editor",
            width = half_width - 2,
            height = prompt_height,
            row = prompt_row,
            col = 0,
            zindex = 4,
            border = { "┌", "─", "┐", "│", "┤", "─", "└", "│" },
        },
        results_icon = {
            relative = "editor",
            width = icon_size,
            height = results_height,
            row = prompt_row + prompt_height + 2, -- border + spacing
            col = 0,
            zindex = 5,
            -- border = "single",
            border = { "├", "─", "─", "", "─", "─", "└", "│" },
        },
        results = {
            relative = "editor",
            width = half_width - 2 - icon_size,
            height = results_height,
            row = prompt_row + prompt_height + 2, -- border + spacing
            col = 3,
            zindex = 1,
            border = { "", "", "", "│", "┘", "─", "", "" },
        },
        preview = {
            relative = "editor",
            width = half_width,
            height = vim.o.lines - prompt_row - prompt_height - 4,
            border = "single",
            row = prompt_row + prompt_height + 2, -- border + spacing
            col = half_width,
            zindex = 1,
        },
    }
end

---Gets all the options for the windows
local get_opts = function()
    return {
        prompt = {
            buf = {},
            win = {
                cursorline = false,
                number = false,
                relativenumber = false,
            },
        },
        results = {
            buf = {},
            win = {
                cursorline = false,
                number = false,
                relativenumber = false,
            },
        },
        results_icon = {
            buf = {},
            win = {
                cursorline = false,
                number = false,
                relativenumber = false,
            },
        },
        preview = {
            buf = {},
            win = {
                cursorline = false,
            },
        },
    }
end

local windo = function(func)
    for kind, value in pairs(state.windows) do
        func(kind, value)
    end
end

local create_windows = function()
    windo(function(kind, value)
        local win_configs = get_win_configs()
        local opts = get_opts()
        if not vim.api.nvim_win_is_valid(value) then
            state.buffers[kind] = vim.api.nvim_create_buf(false, true)
            state.windows[kind] = vim.api.nvim_open_win(state.buffers[kind], false, win_configs[kind])

            for opt, v in pairs(opts[kind].buf) do
                vim.bo[state.buffers[kind]][opt] = v
            end

            for opt, v in pairs(opts[kind].win) do
                vim.wo[state.windows[kind]][opt] = v
            end
        end
    end)

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = state.buffers.prompt,
        callback = function()
            set_options("original")
        end,
    })
end

M.open = function(cwd)
    save_options()
    create_windows()
    set_options("floating")
    cwd = cwd or vim.fn.getcwd()

    vim.api.nvim_set_current_win(state.windows.prompt)
    if M.opts.start_insert then
        vim.cmd([[startinsert]])
    end

    get_entries(cwd)

    -- TODO: better way for icons and content, not iter every time
    vim.api.nvim_buf_set_lines(
        state.buffers.results,
        0,
        -1,
        false,
        vim.iter(state.entries.directories)
            :map(function(entry)
                return entry.text
            end)
            :totable()
    )
end

-- to remove eob
-- vim.opt.fillchars.eob = " "

M.setup = function(opts)
    opts = opts or {}

    M.opts = vim.tbl_deep_extend("keep", opts, M.opts)

    -- vim.print(state.windows)
    -- vim.print(state.buffers)
end

M.setup()
M.open()

return M
