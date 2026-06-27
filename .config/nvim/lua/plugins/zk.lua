return {
    {
        "zk-org/zk-nvim",
        dependencies = { "nvim-telescope/telescope.nvim" },
        -- Set the default notebook so :ZkNew/:ZkNotes work from anywhere.
        -- `init` runs at startup, before the plugin is lazy-loaded.
        init = function()
            vim.env.ZK_NOTEBOOK_DIR = vim.fn.expand "~/Documents/notes"
        end,
        ft = "markdown",
        cmd = {
            "ZkNew",
            "ZkNotes",
            "ZkTags",
            "ZkBacklinks",
            "ZkLinks",
            "ZkMatch",
            "ZkNewFromTitleSelection",
        },
        keys = {
            { "<leader>zn", "<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>", desc = "Zk: new note" },
            { "<leader>zo", "<Cmd>ZkNotes { sort = { 'modified' } }<CR>", desc = "Zk: open notes" },
            {
                "<leader>zf",
                "<Cmd>ZkNotes { sort = { 'modified' }, match = { vim.fn.input('Search: ') } }<CR>",
                desc = "Zk: search notes",
            },
            { "<leader>zt", "<Cmd>ZkTags<CR>", desc = "Zk: tags" },
            { "<leader>zb", "<Cmd>ZkBacklinks<CR>", desc = "Zk: backlinks" },
            { "<leader>zl", "<Cmd>ZkLinks<CR>", desc = "Zk: outbound links" },
            { "<leader>zf", ":'<,'>ZkMatch<CR>", mode = "v", desc = "Zk: match selection" },
            { "<leader>zn", ":'<,'>ZkNewFromTitleSelection<CR>", mode = "v", desc = "Zk: new note from selection" },
        },
        config = function()
            require("zk").setup {
                picker = "telescope",
                lsp = {
                    config = {
                        -- Route zk's LSP completion ([[ link insertion, etc.) through blink.cmp
                        capabilities = require("blink.cmp").get_lsp_capabilities(),
                    },
                    auto_attach = {
                        enabled = true,
                        filetypes = { "markdown" },
                    },
                },
            }
        end,
    },
}
