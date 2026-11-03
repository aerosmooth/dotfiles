-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.clipboard = "unnamedplus"

-- markdown などのスペルチェックで、日本語の文が全部「綴り間違い」扱いになるのを防ぐ
vim.opt.spelllang = { "en", "cjk" }

-- 差分の計算方法を histogram にする（関数の移動や並べ替えで、無関係な行同士が対応づけられにくい）
vim.opt.diffopt:append("algorithm:histogram")

-- Disable unused providers (silences :checkhealth warnings)
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
