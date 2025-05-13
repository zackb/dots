return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"},
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"

      -- Clear any residual configurations to start fresh
      dap.configurations = {}

      dap.adapters.lldb = {
        type = "executable",
        command = "lldb-dap",
        name = "lldb",
      }

      -- Configuration for C++ debugging
      dap.configurations.cpp = {
        {
          name = "Launch",
          type = "lldb", -- Use lldb for C++ debugging
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", "./build/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
        },
      }

      -- Configuration for C (optional, if needed)
      dap.configurations.c = dap.configurations.cpp

      -- Configuration for Rust (optional, if needed)
      dap.configurations.rust = dap.configurations.cpp
    end,
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"

      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
