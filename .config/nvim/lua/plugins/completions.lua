return {
  {
    "hrsh7th/cmp-nvim-lsp"
  },
  {
    "hrsh7th/nvim-cmp",
    version = false,
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
        }, {
          { name = "buffer" },
        }),
      })
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      require('lspconfig').clangd.setup {
        capabilities = capabilities,
      }
    end,
  },
}
