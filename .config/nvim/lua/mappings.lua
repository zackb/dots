vim.keymap.set("n", "<leader>r", function()
    vim.cmd "!cmake --build --preset debug && ./build/debug/meconium"
end, { desc = "Build and run C++ app" })

vim.keymap.set("n", "<leader>fr", function()
    vim.cmd ":browse oldfiles"
end, { desc = "Browse old files" })
