-- ==============================================================================
-- Autocomandos (Autocmds)
-- ==============================================================================

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Resaltar texto copiado (yank) brevemente
local yank_group = augroup("HighlightYank", { clear = true })
autocmd("TextYankPost", {
  group = yank_group,
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Restaurar posición del cursor al reabrir un archivo
local cursor_group = augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
  group = cursor_group,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Cerrar ventanas auxiliares con 'q'
local close_with_q = augroup("CloseWithQ", { clear = true })
autocmd("FileType", {
  group = close_with_q,
  pattern = { "help", "lspinfo", "man", "qf", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})
