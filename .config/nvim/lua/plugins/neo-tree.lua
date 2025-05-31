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
                            -- Open file in new tab
                            vim.cmd("tabnew " .. vim.fn.fnameescape(node.path))

                            -- Defer focus shift to the newly opened file buffer in the new tab
                            vim.defer_fn(function()
                                -- Find the window that is not neo-tree and jump to it
                                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                                    local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
                                    if not bufname:match "neo%-tree" then
                                        vim.api.nvim_set_current_win(win)
                                        break
                                    end
                                end
                            end, 10) -- delay in ms
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
