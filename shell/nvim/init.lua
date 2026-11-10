-- ==============================================================================
-- Neovim - Configuración Principal (Debian Workstation)
-- ==============================================================================

-- Definir teclas líder antes de cargar cualquier plugin
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Cargar configuración base
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Bootstrap de lazy.nvim (gestor de plugins declarativo y veloz)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Error al clonar lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPresiona cualquier tecla para continuar..." },
    }, true, {})
    vim.fn.getchar()
  end
end
vim.opt.rtp:prepend(lazypath)

-- Configuración de lazy.nvim
local ok, lazy = pcall(require, "lazy")
if ok then
  lazy.setup("plugins", {
    defaults = {
      lazy = false,
    },
    install = {
      missing = true,
      colorscheme = { "tokyonight-night", "habamax" },
    },
    checker = {
      enabled = false, -- Sin verificaciones intrusivas en segundo plano
    },
    change_detection = {
      notify = false,
    },
    performance = {
      rtp = {
        disabled_plugins = {
          "gzip",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
    },
  })
end
