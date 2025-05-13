require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<leader>r", function()
  vim.cmd "!cmake --preset debug build && ./build/debug/meconium"
end, { desc = "Build and run C++ app" })

local dap = require "dap"
local dapui = require "dapui"

map("n", "<leader>d", dap.continue, { desc = "Start/Continue Debugger" })
map("n", "<leader>dn", dap.step_over, { desc = "Step Over" })
map("n", "<leader>di", dap.step_into, { desc = "Step Into" })
map("n", "<leader>do", dap.step_out, { desc = "Step Out" })
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })

-- Open/close the UI
map("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })
