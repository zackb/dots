return {
    {
        "stevearc/conform.nvim",
        lazy = false,
        opts = {
            formatters_by_ft = {
                lua = { "stylua" },
                cpp = { "clang_format" },
                c = { "clang_format" },
            },

            format_on_save = function(bufnr)
                local ignore_filetypes =
                    { "scala", "sbt", "python", "javascript", "typescript", "javascriptreact", "typescriptreact" }

                local ft = vim.bo[bufnr].filetype
                if vim.tbl_contains(ignore_filetypes, ft) then
                    return false
                end
                return {
                    timeout_ms = 500,
                    lsp_fallback = true,
                }
            end,
        },
    },
}
