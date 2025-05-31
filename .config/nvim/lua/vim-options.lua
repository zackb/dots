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

-- vim.schedule(function()
--   vim.o.clipboard = 'unnamedplus'
-- end)

vim.o.undofile = false

vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10

-- clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.o.showtabline = 1
vim.o.tabline = "%!v:lua.TabLine()"

function _G.TabLine()
    local s = ""
    for i = 1, vim.fn.tabpagenr("$") do
        local winnr = vim.fn.tabpagewinnr(i)
        local buflist = vim.fn.tabpagebuflist(i)
        local bufnr = buflist[winnr]
        local name = vim.fn.fnamemodify(vim.fn.bufname(bufnr), ":t")
        local tab_label = name ~= "" and name or "[No Name]"
        if i == vim.fn.tabpagenr() then
            s = s .. "%#TabLineSel#"
        else
            s = s .. "%#TabLine#"
        end
        s = s .. " " .. i .. ": " .. tab_label .. " "
    end
    s = s .. "%#TabLineFill#"
    return s
end

