return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "astro",
        "cmake",
        "cpp",
        "css",
        "fish",
        "gitignore",
        "go",
        "graphql",
        "http",
        "java",
        "php",
        "ron",
        "rust",
        "scss",
        "sql",
        "svelte",
        "latex",
        "typst",
        "vue",
        "ninja",
        "rst",
        "lua",
        "vim",
        "vimdoc",
        "query",
      },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        disable = { "vim" },
        additional_vim_regex_highlighting = false,
      },
      indent = { enable = true },

    },
    config = function(_, opts)
      -- MDX
      vim.filetype.add({
        extension = {
          mdx = "mdx",
        },
      })
      vim.treesitter.language.register("markdown", "mdx")
    end,
  },
}
