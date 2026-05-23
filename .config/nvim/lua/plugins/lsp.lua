return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "mason-org/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
            { "j-hui/fidget.nvim", opts = {} },
            "saghen/blink.cmp",
        },
        lazy = false,
        config = function()
            vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
            vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, {})

            vim.diagnostic.config {
                virtual_text = true,
                signs = true,
                underline = true,
                update_in_insert = false,
                severity_sort = true,
            }

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
                callback = function(event)
                    local map = function(keys, func, desc, mode)
                        mode = mode or "n"
                        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
                    end

                    map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
                    map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })
                    map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
                    map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
                    map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
                    map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
                    map("gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")
                    map("gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")
                    map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

                    local client = vim.lsp.get_client_by_id(event.data.client_id)

                    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
                        local hi_group = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
                        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                            buffer = event.buf,
                            group = hi_group,
                            callback = vim.lsp.buf.document_highlight,
                        })
                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                            buffer = event.buf,
                            group = hi_group,
                            callback = vim.lsp.buf.clear_references,
                        })
                        vim.api.nvim_create_autocmd("LspDetach", {
                            group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
                            callback = function(event2)
                                vim.lsp.buf.clear_references()
                                vim.api.nvim_clear_autocmds { group = "kickstart-lsp-highlight", buffer = event2.buf }
                            end,
                        })
                    end

                    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
                        map("<leader>th", function()
                            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
                        end, "[T]oggle Inlay [H]ints")
                    end
                end,
            })

            local capabilities = require("blink.cmp").get_lsp_capabilities()
            vim.lsp.config("*", { capabilities = capabilities })

            local servers = {
                gopls = {},
                terraformls = {},
                ts_ls = {},
                lua_ls = {
                    settings = {
                        Lua = {
                            diagnostics = { globals = { "vim" } },
                        },
                    },
                },
                pyright = {},
                html = {},
                cssls = {},
                bashls = {},
                jsonls = {},
                yamlls = {},
                vimls = {},
                marksman = {},
                clangd = {},
            }

            for server, config in pairs(servers) do
                if next(config) then
                    vim.lsp.config(server, config)
                end
            end

            require("mason-tool-installer").setup {
                ensure_installed = vim.list_extend(vim.tbl_keys(servers), { "stylua" }),
            }

            require("mason-lspconfig").setup {
                ensure_installed = vim.tbl_keys(servers),
                automatic_enable = true,
            }
        end,
    },
}
