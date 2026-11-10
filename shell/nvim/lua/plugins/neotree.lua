return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Explorador de archivos (Árbol)" },
      { "<C-b>", "<cmd>Neotree toggle<CR>", desc = "Alternar árbol lateral (estilo Zed)" },
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      filesystem = {
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = {
          enabled = true,
        },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 30,
        mappings = {
          ["<space>"] = "none",
          ["<cr>"] = "open",
          ["o"] = "open",
          ["a"] = { "add", config = { show_path = "none" } },
          ["d"] = "delete",
          ["r"] = "rename",
          ["c"] = "copy_to_clipboard",
          ["x"] = "cut_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["H"] = "toggle_hidden",
        },
      },
    },
  },
}
