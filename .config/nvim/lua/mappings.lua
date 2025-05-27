vim.keymap.set("n", "<leader>r", function()
    vim.cmd "!cmake --build --preset debug && ./build/debug/meconium"
end, { desc = "Build and run C++ app" })

vim.keymap.set("n", "<leader>fr", function()
    vim.cmd ":browse oldfiles"
end, { desc = "Browse old files" })

vim.keymap.set("n", "<leader>e", function()
    vim.cmd ":Neotree reveal"
end, { desc = "Reveal current file" })

vim.keymap.set("n", "<leader>q", "<cmd>Telescope diagnostics bufnr=0<cr>", { desc = "Show diagnostics for buffer" })
