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

                    local function client_supports_method(client, method, bufnr)
                        if vim.fn.has "nvim-0.11" == 1 then
                            return client:supports_method(method, bufnr)
                        else
                            return client.supports_method(method, { bufnr = bufnr })
                        end
                    end

                    local client = vim.lsp.get_client_by_id(event.data.client_id)
                    if
                        client
                        and client_supports_method(
                            client,
                            vim.lsp.protocol.Methods.textDocument_documentHighlight,
                            event.buf
                        )
                    then
                        local highlight_augroup =
                            vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
                        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                            buffer = event.buf,
                            group = highlight_augroup,
                            callback = vim.lsp.buf.document_highlight,
                        })

                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                            buffer = event.buf,
                            group = highlight_augroup,
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

                    if
                        client
                        and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
                    then
                        map("<leader>th", function()
                            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
                        end, "[T]oggle Inlay [H]ints")
                    end
                end,
            })

            local capabilities = require("blink.cmp").get_lsp_capabilities()

            local servers = {
                gopls = {},
                terraformls = {},
                ts_ls = {},
                lua_ls = {},
                pyright = {},
                html = {},
                cssls = {},
                bashls = {},
                jsonls = {},
                yamlls = {},
                vimls = {},
                marksman = {},
            }

            local ensure_installed = vim.tbl_keys(servers or {})
            vim.list_extend(ensure_installed, {
                "stylua",
            })

            require("mason-tool-installer").setup { ensure_installed = ensure_installed }
            require("mason-lspconfig").setup {
                ensure_installed = vim.tbl_keys(servers),
                automatic_installation = false,
                handlers = {
                    function(server_name)
                        local server = servers[server_name] or {}
                        server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})

                        vim.lsp.config[server_name] = vim.tbl_deep_extend("force", {
                            capabilities = server.capabilities,
                            cmd = server.cmd,
                            filetypes = server.filetypes,
                            root_dir = server.root_dir,
                            settings = server.settings,
                        }, server)
                        vim.lsp.enable(server_name)
                    end,
                },
            }
        end,
    },
}
