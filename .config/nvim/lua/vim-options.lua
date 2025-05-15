vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.showtabline = 1

vim.opt.foldmethod = "marker"

vim.opt.incsearch = true

vim.opt.swapfile = false
vim.opt.number = true
vim.opt.autoindent = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = false

vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

vim.o.undofile = true

vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10

-- clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

