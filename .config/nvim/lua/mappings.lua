vim.keymap.set("n", "<leader>r", function()
  vim.cmd "!cmake --preset debug build && ./build/debug/meconium"
end, { desc = "Build and run C++ app" })
