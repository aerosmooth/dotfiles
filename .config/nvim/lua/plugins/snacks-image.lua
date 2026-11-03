-- 画像（png・jpg・pdf など）を nvim の中で表示する（ファイルを開く、ファイル検索のプレビュー、markdown 内の画像と数式）
-- 端末が kitty graphics に対応している必要がある（Ghostty は対応）。tmux の中では snacks が自動で passthrough を有効にする
-- png 以外の変換に ImageMagick（magick か convert）、pdf にはさらに ghostscript（gs）を使う
return {
  "snacks.nvim",
  opts = {
    image = { enabled = true },
  },
}
