return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(args)
                    local buf = args.buf
                    local lang = vim.treesitter.language.get_lang(args.match)
                    if lang and pcall(vim.treesitter.start, buf, lang) then
                    -- Tree-sitter started successfully
                    else
                        -- Optionally fallback to regex syntax if tree-sitter fails
                        -- vim.bo[buf].syntax = "ON"
                    end
                end,
            })
        end,
    },
}
