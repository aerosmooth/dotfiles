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

-- AI（Claude Code など）が外からファイルを書き換えたら、開いているバッファにすぐ反映する。
-- LazyVim 標準はフォーカスが戻ったときしか確認しないので、横の画面で書き換えられても気づけない。
-- そこで 1 秒ごとに確認する。未保存の変更があるバッファは対象外（確認ダイアログで入力を邪魔しないため）
local reload_timer = vim.uv.new_timer()
if reload_timer then
  reload_timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      local mode = vim.api.nvim_get_mode()
      if mode.blocking or not vim.tbl_contains({ "n", "i", "nt", "t" }, mode.mode) or vim.fn.getcmdwintype() ~= "" then
        return
      end
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if
          vim.api.nvim_buf_is_loaded(buf)
          and vim.bo[buf].buftype == ""
          and not vim.bo[buf].modified
          and name ~= ""
          and vim.uv.fs_stat(name) -- 消されたファイルは確認しない（毎秒イベントが起きるため）
        then
          pcall(vim.cmd.checktime, tostring(buf))
        end
      end
    end)
  )
end

-- 再読み込みしたファイルを通知する（git checkout などで一度に変わったときは 1 回にまとめる）
local reloaded_files = {}
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = vim.api.nvim_create_augroup("notify_external_reload", { clear = true }),
  callback = function(ev)
    if not vim.uv.fs_stat(ev.match) then
      return -- 消されたときは nvim 自身が E211 で知らせる
    end
    if #reloaded_files == 0 then
      vim.defer_fn(function()
        vim.notify("外部で変更されたので再読み込みしました:\n" .. table.concat(reloaded_files, "\n"))
        reloaded_files = {}
      end, 200)
    end
    table.insert(reloaded_files, vim.fn.fnamemodify(ev.file, ":~:."))
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python" },
  callback = function()
    vim.cmd('iabbr ifmain if __name__ == "__main__":<Enter>main()<Left>')
    vim.cmd("iabbr frang for i in range():<Left><Left>")
    vim.cmd(
      'iabbr ifstart import sys<Enter>def solve():<Enter>input_data = sys.stdin.read().split()<Enter><BS>if __name__ == "__main__":<Enter>solve()'
    )
  end,
})
