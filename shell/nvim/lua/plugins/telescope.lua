return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Buscar archivos" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Buscar texto (grep)" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Listar buffers abiertos" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Buscar ayuda" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Archivos recientes" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          prompt_prefix = "   ",
          selection_caret = "  ",
          entry_prefix = "  ",
          sorting_strategy = "ascending",
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width = 0.55,
            },
          },
          file_ignore_patterns = { "node_modules", ".git/", "__pycache__" },
        },
      })
    end,
  },
}
