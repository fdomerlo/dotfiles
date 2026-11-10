-- ==============================================================================
-- Atajos de Teclado (Keymaps)
-- ==============================================================================

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Leader = Espacio (definido en init.lua)

-- Atajos familiares estilo Zed / VS Code
-- Guardar con Ctrl+S en cualquier modo
map({ "n", "i", "v" }, "<C-s>", "<cmd>write<CR><Esc>", { desc = "Guardar archivo (Ctrl+S)", noremap = true, silent = true })

-- Búsqueda de archivos rápida con Ctrl+P
map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Buscar archivos (Ctrl+P)" })

-- Alternar árbol de directorios lateral con Ctrl+B o <leader>e
map("n", "<C-b>", "<cmd>Neotree toggle<CR>", { desc = "Explorador de archivos (Ctrl+B)" })
map("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "Explorador de archivos" })

-- Navegación rápida de pestañas (buffers) con Shift+H / Shift+L
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Pestaña anterior" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Siguiente pestaña" })

-- Guardado y salida con Leader
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Guardar archivo", noremap = true, silent = true })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Cerrar ventana actual", noremap = true, silent = true })
map("n", "<leader>Q", "<cmd>qa!<CR>", { desc = "Forzar cierre de todo", noremap = true, silent = true })

-- Limpiar resaltado de búsqueda con <Esc>
map("n", "<Esc>", "<cmd>nohlsearch<CR>", opts)

-- Navegación fluida entre splits (coherente con tmux y hjkl)
map("n", "<C-h>", "<C-w>h", { desc = "Mover foco a la izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Mover foco hacia abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Mover foco hacia arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Mover foco a la derecha" })

-- Manejo de divisiones (splits)
map("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Dividir verticalmente" })
map("n", "<leader>sh", "<cmd>split<CR>", { desc = "Dividir horizontalmente" })
map("n", "<leader>se", "<C-w>=", { desc = "Igualar tamaño de divisiones" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Cerrar división actual" })

-- Navegación de buffers
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Buffer anterior" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "Siguiente buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Cerrar buffer actual" })

-- Mover bloques de código seleccionados en modo visual con J y K
map("v", "J", ":m '>+1<CR>gv=gv", opts)
map("v", "K", ":m '<-2<CR>gv=gv", opts)

-- Mantener indentación tras sangrar en modo visual
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- No sobreescribir el registro al pegar sobre una selección
map("x", "p", [["_dP]], opts)
