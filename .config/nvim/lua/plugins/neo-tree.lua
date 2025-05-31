return {
    "nvim-neo-tree/neo-tree.nvim",
    version = "*",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    lazy = false,
    keys = {
        { "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
    },
    opts = {
        filesystem = {
            filtered_items = {
                visible = true,
            },
            window = {
                mappings = {
                    ["\\"] = "close_window",
                    ["<C-t>"] = function(state)
                        local node = state.tree:get_node()
                        if node and node.path then
                            vim.cmd("tabnew " .. vim.fn.fnameescape(node.path))
                        end
                    end,
                },
            },
        },
    },
    config = function(_, opts)
        require("neo-tree").setup(opts)

        -- Auto-open Neo-tree on new tabs
        vim.api.nvim_create_autocmd("TabNewEntered", {
            callback = function()
                require("neo-tree.command").execute { toggle = false, reveal = true, focus = false }
            end,
        })
    end,
}
