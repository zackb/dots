return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local wanted = {
                "bash",
                "c",
                "cpp",
                "css",
                "diff",
                "go",
                "html",
                "javascript",
                "json",
                "lua",
                "markdown",
                "markdown_inline",
                "python",
                "query",
                "rust",
                "toml",
                "typescript",
                "vim",
                "vimdoc",
                "yaml",
            }
            local installed = require("nvim-treesitter.config").get_installed()
            local to_install = vim.iter(wanted)
                :filter(function(p)
                    return not vim.tbl_contains(installed, p)
                end)
                :totable()
            if #to_install > 0 then
                require("nvim-treesitter").install(to_install)
            end

            -- highlighting per filetype
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(args)
                    local buf = args.buf
                    local lang = vim.treesitter.language.get_lang(args.match)
                    if lang then
                        pcall(vim.treesitter.start, buf, lang)
                    end
                end,
            })
        end,
    },
}
