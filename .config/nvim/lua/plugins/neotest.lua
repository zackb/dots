return {
    {
        "nvim-neotest/neotest",
        dependencies = {
            "fredrikaverpil/neotest-golang",
            "nvim-neotest/nvim-nio",
            "nvim-lua/plenary.nvim",
            "antoinemadec/FixCursorHold.nvim",
        },
        config = function()
            require("neotest").setup {
                adapters = {
                    require "neotest-golang" {
                        -- droped -race for cgo reasons, add it back to do race stuff
                        go_test_args = { "-v", "-count=1" },
                    },
                },
            }
            local nt = require "neotest"
            vim.keymap.set("n", "<leader>tt", nt.run.run, { desc = "Test nearest" })
            vim.keymap.set("n", "<leader>tf", function()
                nt.run.run(vim.fn.expand "%")
            end, { desc = "Test file" })
            vim.keymap.set("n", "<leader>ta", function()
                nt.run.run(vim.fn.getcwd())
            end, { desc = "Test all" })
            vim.keymap.set("n", "<leader>ts", nt.summary.toggle, { desc = "Test summary" })
            vim.keymap.set("n", "<leader>to", nt.output.open, { desc = "Test output" })
        end,
    },
}
