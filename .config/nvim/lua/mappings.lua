vim.keymap.set("n", "<leader>r", function()
    vim.cmd "!cmake --build --preset debug && ./build/debug/meconium"
end, { desc = "Build and run C++ app" })
