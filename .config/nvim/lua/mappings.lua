vim.keymap.set("n", "<leader>r", function()
    vim.cmd "!cmake --build --preset debug && ./build/debug/meconium/meconium"
end, { desc = "Build and run C++ app" })

vim.keymap.set("n", "<leader>fr", function()
    vim.cmd ":Telescope oldfiles"
end, { desc = "Browse old files" })

vim.keymap.set("n", "<leader>e", function()
    vim.cmd ":Neotree reveal"
end, { desc = "Reveal current file" })

vim.keymap.set("n", "<leader>q", "<cmd>Telescope diagnostics bufnr=0<cr>", { desc = "Show diagnostics for buffer" })

-- yank to system clipboard
vim.keymap.set("n", "y", '"+y')
vim.keymap.set("v", "y", '"+y')
--
-- clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
