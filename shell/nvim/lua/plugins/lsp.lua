return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
      if cmp_ok then
        capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
      end

      local on_attach = function(_, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
        end

        map("gd", vim.lsp.buf.definition, "Ir a definición")
        map("gr", vim.lsp.buf.references, "Listar referencias")
        map("gI", vim.lsp.buf.implementation, "Ir a implementación")
        map("K", vim.lsp.buf.hover, "Mostrar documentación flotante")
        map("<leader>rn", vim.lsp.buf.rename, "Renombrar símbolo")
        map("<leader>ca", vim.lsp.buf.code_action, "Acción de código")
        map("<leader>e", vim.diagnostic.open_float, "Mostrar diagnóstico")
        map("[d", vim.diagnostic.goto_prev, "Diagnóstico anterior")
        map("]d", vim.diagnostic.goto_next, "Siguiente diagnóstico")
      end

      -- Autocomando global de LspAttach para asegurar atajos en cualquier LSP
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(ev)
          on_attach(nil, ev.buf)
        end,
      })

      local lspconfig = require("lspconfig")
      local mason_lspconfig = require("mason-lspconfig")

      mason_lspconfig.setup({
        -- LSPs instalados por defecto
        ensure_installed = {
          "lua_ls",
          "bashls",
        },
        automatic_installation = true,
      })

      -- En Neovim 0.11+ se utiliza la API nativa vim.lsp.config
      if vim.lsp.config then
        vim.lsp.config("*", {
          capabilities = capabilities,
        })
        vim.lsp.config("lua_ls", {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                checkThirdParty = false,
              },
            },
          },
        })
      end

      -- Compatibilidad con mason-lspconfig v1 (setup_handlers) si estuviera presente
      if type(mason_lspconfig.setup_handlers) == "function" then
        mason_lspconfig.setup_handlers({
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities,
              on_attach = on_attach,
            })
          end,
          ["lua_ls"] = function()
            lspconfig.lua_ls.setup({
              capabilities = capabilities,
              on_attach = on_attach,
              settings = {
                Lua = {
                  diagnostics = {
                    globals = { "vim" },
                  },
                  workspace = {
                    checkThirdParty = false,
                  },
                },
              },
            })
          end,
        })
      elseif not vim.lsp.config then
        -- Fallback para versiones previas sin vim.lsp.config ni setup_handlers
        lspconfig.lua_ls.setup({
          capabilities = capabilities,
          on_attach = on_attach,
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                checkThirdParty = false,
              },
            },
          },
        })
        lspconfig.bashls.setup({
          capabilities = capabilities,
          on_attach = on_attach,
        })
      end
    end,
  },
}
