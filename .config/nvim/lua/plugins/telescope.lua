return {
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.5",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local builtin = require("telescope.builtin")
            vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find Files" })
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live Grep" })
            vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
            vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help Tags" })
            vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Symbols" })

            vim.keymap.set("n", "<leader>gc", builtin.git_commits, { desc = "Git Commits" })
            vim.keymap.set("n", "<leader>gb", builtin.git_branches, { desc = "Git Branches" })
            vim.keymap.set("n", "<leader>gs", builtin.git_status, { desc = "Git Status" })
        end
    }
}
