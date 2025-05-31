return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "-" },
            },
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local map = function(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
                end

                -- Hunk nav
                map("n", "]c", function()
                    gs.nav_hunk "next"
                end, "Next hunk")
                map("n", "[c", function()
                    gs.nav_hunk "prev"
                end, "Prev hunk")

                -- Hunk actions
                map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
                map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
                map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
                map("n", "<leader>hb", function()
                    gs.blame_line { full = true }
                end, "Blame line")
            end,
        },
    },

    -- Full git support
    {
        "tpope/vim-fugitive",
        cmd = { "Git", "Gstatus", "Gdiffsplit", "Gcommit", "Gpush", "Gpull", "Gblame" },
        config = function()
            local map = vim.api.nvim_set_keymap
            local opts = { noremap = true, silent = true }

            map("n", "<leader>gs", ":Git<CR>", opts)
            map("n", "<leader>gd", ":Gdiffsplit<CR>", opts)
            map("n", "<leader>gf", ":Git add %<CR>", opts)
            map("n", "<leader>gc", ":Git commit<CR>", opts)
            map("n", "<leader>gp", ":Git push<CR>", opts)
            map("n", "<leader>gl", ":Git pull<CR>", opts)
            map("n", "<leader>gb", ":Git blame<CR>", opts)
        end,
    },
}
