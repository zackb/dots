return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local harpoon = require "harpoon"
            harpoon:setup()
            local list = harpoon:list()

            vim.keymap.set("n", "<leader>ha", function()
                list:add()
            end, { desc = "Harpoon add file" })
            vim.keymap.set("n", "<leader>hr", function()
                list:remove()
            end, { desc = "Harpoon remove file" })
            vim.keymap.set("n", "<leader>h", function()
                harpoon.ui:toggle_quick_menu(list)
            end, { desc = "Harpoon quick menu" })

            -- Navigate to files
            vim.keymap.set("n", "<leader>1", function()
                list:select(1)
            end)
            vim.keymap.set("n", "<leader>2", function()
                list:select(2)
            end)
            vim.keymap.set("n", "<leader>3", function()
                list:select(3)
            end)
            vim.keymap.set("n", "<leader>4", function()
                list:select(4)
            end)
        end,
    },
}
