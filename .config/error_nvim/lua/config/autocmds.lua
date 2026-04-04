-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
---- 環境変数 NVIM_AUTO_PICKER が config だったら設定ファイルを開く
if vim.env.NVIM_AUTO_PICKER == "config" then
  vim.schedule(function()
    require("lazyvim.util.pick").config_files()()
  end)
end
