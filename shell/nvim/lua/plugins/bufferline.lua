return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Fijar pestaña" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Cerrar pestañas no fijadas" },
      { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Cerrar otras pestañas" },
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Pestaña anterior" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Siguiente pestaña" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Pestaña anterior" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Siguiente pestaña" },
    },
    opts = {
      options = {
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorador de Archivos",
            highlight = "Directory",
            text_align = "left",
          },
        },
      },
    },
  },
}
