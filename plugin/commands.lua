vim.api.nvim_create_user_command("FileBrowser", function(tbl)
    local args = tbl.args
    if not require("file_browser").is_set_up() then
        require("file_browser").setup({})
    end
    if #args > 0 then
        require("file_browser").open(args[1])
    else
        require("file_browser").open()
    end
end, {})
