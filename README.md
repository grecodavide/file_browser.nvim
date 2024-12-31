# file_browser.nvim

This plugin aims to provide a file browser similar to the one provided by telescope extension,
without necessarily using telescope.

## External dependencies
- `fzf`
- `fd`

## Showcase
![Preview](https://imgur.com/QflGv63.gif)

## Available actions
| Action | Argument | Description |
| --------------- | --------------- | ---------- |
|`scroll_preview_up` | `{}` | Scrolls the preview up | 
|`scroll_preview_down` | `{}` | Scrolls the preview down | 
|`default` | `{cd: boolean?}` | If current entry is a directory, go to it, else open the file. If `cd` is true, updates neovim cwd | 
|`move_to_cwd` | `{delete_selection: boolean?}` | Moves selection to cwd. By default, after a successful move, it will also remove from the marked list. Passing `false` to this call will avoid that | 
|`copy_to_cwd` | `{delete_selection: boolean?}` | Copies selection to cwd. By default, after a successful move, it will also remove from the marked list. Passing `false` to this call will avoid that | 
|`cd` | `{}` | Changes nvim CWD to this plugin's | 
|`rename` | `{}` | Renames current entry | 
|`mark_current` | `{}` | Marks current entry as selected | 
|`delete` | `{force: boolean?, ask_confirmation: boolean?}` | Deletes a file/folder. `force` is false by default, and `ask_confirmation` true by default | 
|`close` | `{}` | Closes all this plugin's windows | 
|`create` | `{jump: boolean?}` | Creates a file/folder. Can be nested. Unless `jump` is set to `false`, also cd to directory/open file created | 
|`goto_parent` | `{start_insert: boolean?}` | Goes to parent directory. Unless `start_insert` is set to false, puts in insert mode | 
|`goto_parent_or_delete` | `{}` | If prompt is empty, go to parent directory. Otherwise, behave like a regular `<BS>` | 
|`jump_to` | `{index: number, absolute: boolean?}` | Jump to given entry (considered relative unless `absolute` is set to true | 
|`open_split` | `{vertical: boolean?}` | If current entry is a file, opens it in a split. Defaults to vsplit | 


## Default mappings

| Mode | Mapping | Action | Arguments |
| --------------- | --------------- | ---------- | ---------- |
| `n` | `<Esc>` | `close` | `{}` | 
| `{n, i}` | `<C-s>` | `mark_current` | `{}` | 
| `{n, i}` | `<C-m>` | `move_to_cwd` | `{}` | 
| `{n, i}` | `<C-y>` | `copy_to_cwd` | `{}` | 
| `i` | `<C-.>` | `cd` | `{}` | 
| `n` | `.` | `cd` | `{}` | 
| `n` | `r` | `rename` | `{}` | 
| `{n, i}` | `<C-d>` | `scroll_preview_down` | `{}` | 
| `{n, i}` | `<C-u>` | `scroll_preview_up` | `{}` | 
| `{n, i}` | `<C-n>` | `jump` | `{1}` | 
| `n` | `j` | `jump` | `{1}` | 
| `{n, i}` | `<C-p>` | `jump` | `{-1}` | 
| `n` | `k` | `jump` | `{-1}` | 
| `{n, i}` | `<CR>` | `default` | `{}` | 
| `{n, i}` | `<C-CR>` | `default` | `{true}` | 
| `{n, i}` | `<C-v>` | `open_split` | `{}` | 
| `{n, i}` | `<C-e>` | `create` | `{}` | 
| `n` | `e` | `create` | `{}` | 
| `{n, i}` | `<C-x>` | `delete` | `{true}` | 
| `n` | `d` | `delete` | `{true}` | 
| `{n, i}` | `<BS>` | `goto_parent_or_delete` | `{}` | 

## Configuration

| Option | Type | Description |
| --------------- | --------------- | ---------- |
| `start_insert` | `boolean` | Whether we should start in insert mode. Defaults to true |
| `display_symlinks` | `boolean` | Wehter we should show symlinks or not. Defaults to true |
| `width_scale` | `number` | Defaults to 0.92 |
| `height_scale` | `number` | Defaults to 0.92 |
| `show_hidden` | `boolean` | Defaults to true |
| `show_links` | `boolean` | Defaults to true |
| `marked_icons` | `file_browser.MarkIcons` | Icons used for marks |
| `debounce` | `number` | debounce for preview (in ms) |
| `preview_width` | `number` | percentage of floating win to be used for preview |
| `max_prompt_size` | `number` | max size (percentage) of prompt prefix |
| `use_treesitter` | `boolean` | Defaults to true |
| `mappings` | `file_browser.Mapping[]?` | Mappings |
| `use_default_mappings` | `boolean?` | Use a default set of mappings. Defaults to true |
| `group_dirs` | `boolean?` | Whether directories should be grouped at the top |

## Setup

Example using lazy:
```lua
return {
return {
    "grecodavide/file_browser.nvim",
    lazy = false,
    config = function()
        -- mandatory. Plugin won't work if this does not get called
        require("file_browser").setup({
            width_scale = 0.95,
            height_scale = 0.9,
        })
    end,
    keys = {
        {
            "<leader>fe",
            function()
                require("file_browser").open(vim.fn.expand("%:p:h"))
            end,

            desc = "[F]ile [E]xplorer current file",
        },
        {
            "<leader>fE",
            function()
                require("file_browser").open()
            end,

            desc = "[F]ile [E]xplorer CWD",
        },
    }
}
```

## WIP
- [ ] Bulk rename
- [ ] Preview timeout
- [ ] Still have to correctly merge `default_mappings` to custom


> [!WARNING]
> functions that modify a buffer's text must be called synchronously, so 
> be careful hovering too big of a file, as it could lock you for a while


# Credits
Layout and behavior is inspired by [telescope file browser](https://github.com/nvim-telescope/telescope-file-browser.nvim)
