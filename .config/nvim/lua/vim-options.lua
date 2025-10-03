vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.shiftwidth = 4

vim.opt.foldmethod = "marker"

vim.opt.incsearch = true

vim.opt.swapfile = false
vim.opt.number = true
vim.opt.autoindent = true
vim.opt.smartindent = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = false

vim.opt.termguicolors = true
vim.opt.swapfile = false

vim.opt.title = true
vim.opt.titlestring = "vim %t"

-- vim.schedule(function()
--   vim.o.clipboard = 'unnamedplus'
-- end)

vim.o.undofile = false

vim.o.inccommand = "split"
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.opt.colorcolumn = "80"

vim.o.showtabline = 1
vim.o.tabline = "%!v:lua.TabLine()"

-- Use 2 spaces for JavaScript and Python
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact", "python" },
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
    end,
})

function _G.TabLine()
    local s = ""
    for i = 1, vim.fn.tabpagenr "$" do
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

vim.o.updatetime = 250
vim.cmd [[autocmd CursorHold * lua vim.diagnostic.open_float(nil, {focus=false})]]
