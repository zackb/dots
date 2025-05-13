return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local config = require("nvim-treesitter.configs")
      config.setup({
        auto_install = false,
        ensure_installed = {
          "bash",
          "html",
          "css",
          "javascript",
          "json",
          "lua",
          "cpp",
          "c",
          "java",
          "go",
        },
        highlight = { enable = true },
        indent = { enable = false },
      })
    end
  }
}
