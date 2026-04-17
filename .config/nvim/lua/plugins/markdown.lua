return {
  -- A. ブラウザ同期プレビュー (MarkdownPreview)
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewConfirm", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
  },

  -- B. エディタ内の見た目をリッチにする (Render Markdown)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {}, -- デフォルト設定で起動
    ft = { "markdown" },
  },
}
