return {
    {
        "rose-pine/neovim",
        name = "rose-pine",
        config = function()
            require("rose-pine").setup {
                styles = {
                    italic = false,
                },
            }
            vim.cmd "colorscheme rose-pine"
        end,
    },
    {
        "projekt0n/github-nvim-theme",
        name = "github-theme",
        lazy = false,
        priority = 1000,
        config = function()
            require("github-theme").setup {
                -- ...
            }

            -- vim.cmd "colorscheme github_dark_default"
        end,
    },
    {
        "catppuccin/nvim",
        lazy = false,
        name = "catppuccin",
        priority = 1000,

        config = function()
            require("catppuccin").setup {
                transparent_background = true,
            }
            -- vim.cmd.colorscheme "catppuccin-mocha"
        end,
    },
}
