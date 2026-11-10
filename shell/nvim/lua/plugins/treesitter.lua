return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash",
          "c",
          "diff",
          "html",
          "javascript",
          "json",
          "lua",
          "luadoc",
          "markdown",
          "markdown_inline",
          "python",
          "query",
          "regex",
          "toml",
          "vim",
          "vimdoc",
          "yaml",
        },
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },
}
