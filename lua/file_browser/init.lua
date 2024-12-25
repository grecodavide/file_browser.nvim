local M = {}
local mini_icons = require("mini.icons")

---@class file_browser.Icon
---@field text string: The icon text
---@field hl string: The Highlight group

---@class file_browser.Icons
---@field texts table|string: The icons text. If string, it means they are all the same
---@field hls string[]|string: The Highlight groups. If string, it means they are all the same

---@class file_browser.Entry
---@field text string: text
---@field icon file_browser.Icon: icon

---@class file_browser.Entries
---@field texts string[]: text
---@field icons file_browser.Icons: icon

---@class file_browser.Layout
---@field prompt integer
---@field results integer
---@field results_icon integer
---@field preview integer

---@class file_browser.State
---@field windows file_browser.Layout: the Windows ID (initialized at invalid values)
---@field buffers file_browser.Layout: the Buffers ID (initialized at invalid values)
---@field entries table<string, file_browser.Entries>: the Buffers ID (initialized at invalid values)
local state = {
    windows = {
        prompt = -1,
        results_icon = -1,
        results = -1,
        preview = -1,
        padding = -1,
    },

    buffers = {
        prompt = -1,
        results_icon = -1,
        results = -1,
        preview = -1,
        padding = -1,
    },

    entries = {
        files = {
            texts = {},
            icons = {
                texts = {},
                hls = {},
            },
        },
        directories = {
            texts = {},
            icons = {
                texts = "MiniIconsBlue",
                hls = "",
            },
        },
        links = {
            texts = {},
            icons = {
                texts = "MiniIconsBlue",
                hls = "󱅷",
            },
        },
    },
}

---Gets the windows configuration, used to create such windows
---@return table: The config for prompt, results and preview window
local get_win_configs = function()
    local width = vim.o.columns
    local half_width = bit.rshift(width, 1) - 2 -- remove 2 for padding

    local prompt_row = 1
    local prompt_height = 1

    local results_height = vim.o.lines - prompt_row - prompt_height - 4
    local icon_size = 2

    local results_row = prompt_height + 2

    ---@type table<string, vim.api.keyset.win_config>
    return {
        prompt = {
            relative = "editor",
            width = half_width - 2,
            height = prompt_height,
            row = 0,
            col = 0,
            zindex = 4,
            border = { "┌", "─", "┐", "│", "┤", "─", "├", "│" },
            noautocmd = true,
        },
        padding = {
            relative = "editor",
            width = 1,
            height = results_height,
            row = results_height, -- border + spacing
            col = 0,
            zindex = 6,
            border = { "│", " ", " ", " ", "─", "─", "└", "│" },
        },
        results_icon = {
            relative = "editor",
            width = icon_size,
            height = results_height,
            row = results_row,
            col = icon_size,
            zindex = 6,
            border = { " ", " ", " ", " ", "─", "─", " ", " " },
        },
        results = {
            relative = "editor",
            width = half_width - 5 - icon_size,
            height = results_height,
            row = results_row,
            col = icon_size + 3,
            zindex = 1,
            border = { " ", " ", "│", "│", "┘", "─", " ", " " },
        },
        preview = {
            relative = "editor",
            width = half_width,
            height = vim.o.lines - prompt_row - prompt_height - 4,
            border = "single",
            row = prompt_row + prompt_height + 3, -- border + spacing
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
                signcolumn = "no",
            },
        },
        results = {
            buf = {},
            win = {
                cursorline = false,
                number = false,
                relativenumber = false,
                signcolumn = "no",
            },
        },
        results_icon = {
            buf = {},
            win = {
                cursorline = false,
                number = false,
                relativenumber = false,
                signcolumn = "no",
            },
        },
        preview = {
            buf = {},
            win = {
                cursorline = false,
            },
        },

        padding = {
            buf = {},
            win = {
                cursorline = false,
            },
        },
    }
end

---@class file_browser.Config
---@field start_insert boolean: Whether we should start in insert mode
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

local function get_entries(cwd)
    -- state.entries.files = vim.iter(get_cmd(cwd, "f")):map(transform)
    state.entries.directories.icons = { texts = {}, hls = {} }
    state.entries.directories.texts = {}

    local directories = get_cmd(cwd, "d")
    for _, dir in pairs(directories) do
        if dir and dir ~= "" then
            table.insert(state.entries.directories.texts, dir)
        end
    end

    state.entries.links.texts = {}
    local links = get_cmd(cwd, "l")
    for _, link in pairs(links) do
        if link and link ~= "" then
            table.insert(state.entries.links.texts, link)
        end
    end

    state.entries.files.texts = {}
    local files = get_cmd(cwd, "f")
    local icons = {}
    local hls = {}
    for _, file in pairs(files) do
        if file and file ~= "" then
            local entry = transform(file)
            table.insert(state.entries.files.texts, entry.text)

            table.insert(icons, entry.icon.text)
            table.insert(hls, entry.icon.hl)
        end
    end
    state.entries.files.icons.texts = icons
    state.entries.files.icons.hls = hls
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

    vim.bo[state.buffers.prompt].filetype = "prompt"

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

    for t, entry_type in pairs({ f = "files", d = "directories", l = "links" }) do
        local entry = state.entries[entry_type]

        if type(entry.icons.texts) == "string" then
            -- code
        else
            vim.api.nvim_buf_set_lines(state.buffers.results, 0, -1, false, entry.texts)
            ---@diagnostic disable-next-line: param-type-mismatch
            vim.api.nvim_buf_set_lines(state.buffers.results_icon, 0, -1, false, entry.icons.texts)

            ---@diagnostic disable-next-line: param-type-mismatch
            for linenr, hl in pairs(entry.icons.hls) do
                vim.api.nvim_buf_add_highlight(state.buffers.results, 0, hl, linenr, 0, -1)
                vim.api.nvim_buf_add_highlight(state.buffers.results_icon, 0, hl, linenr, 0, -1)
            end
        end
    end
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
M.open("~/shiny-potato/c")

return M
