-- ==============================================================================
-- Opciones Generales de Neovim
-- ==============================================================================

local opt = vim.opt

-- Numeración de líneas
opt.number = true
opt.relativenumber = true

-- Indentación y tabulaciones (2 espacios por defecto, coherente con el repo)
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

-- Búsqueda
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Aspecto y UI
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Comportamiento y buffers
opt.mouse = "a"
opt.clipboard = "unnamedplus" -- Integración nativa con wl-clipboard / X11
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.updatetime = 250
opt.timeoutlen = 300
