require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<leader>r", function()
  vim.cmd "!cmake --preset debug build && ./build/debug/meconium"
end, { desc = "Build and run C++ app" })
