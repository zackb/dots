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

            format_on_save = {
                timeout_ms = 500,
                lsp_fallback = true,
            },
        }
    },
}
