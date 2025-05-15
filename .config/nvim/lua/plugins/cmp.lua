return {
    { 
        'saghen/blink.cmp',
            event = 'VimEnter',
            version = '1.*',
            dependencies = {
                -- Snippet Engine
                {
                    'L3MON4D3/LuaSnip',
                    version = '2.*',
                    dependencies = {
                        {
                            'rafamadriz/friendly-snippets',
                            config = function()
                                require('luasnip.loaders.from_vscode').lazy_load()
                                end,
                        },
                    },
                    opts = {},
                },
                'folke/lazydev.nvim',
            },
            opts = {
                keymap = {
                    preset = 'default',
                },
                appearance = {
                    nerd_font_variant = 'normal',
                },

                completion = {
                    documentation = { auto_show = false, auto_show_delay_ms = 500 },
                },
                sources = {
                    default = { 'lsp', 'path', 'snippets', 'lazydev' },
                    providers = {
                        lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
                    },
                },

                snippets = { preset = 'luasnip' },
                fuzzy = { implementation = 'lua' },
                signature = { enabled = true },
            },
    },
}
