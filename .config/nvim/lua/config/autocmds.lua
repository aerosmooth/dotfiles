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

_G.lazyvim_python_atstart_expand = function()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local text = table.concat({
    "import sys",
    "",
    "def read_input():",
    "    input_data = sys.stdin.read().split()",
    "",
    "    return ",
    "",
    "def solve():",
    "    = read_input()",
    "",
    'if __name__ == "__main__":',
    "    solve()",
  }, "\n")

  vim.schedule(function()
    vim.api.nvim_paste(text, false, -1)
    vim.schedule(function()
      local first = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
      if first:match("^ ") then
        vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, 1, { "" })
      end
    end)
  end)

  return ""
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python" },
  callback = function()
    vim.cmd('iabbr ifmain if __name__ == "__main__":<Enter>main()<Left>')
    vim.cmd("iabbr frang for i in range():<Left><Left>")
    vim.cmd(
      'iabbr ifstart import sys<Enter>def solve():<Enter>input_data = sys.stdin.read().split()<Enter><BS>if __name__ == "__main__":<Enter>solve()'
    )
    vim.cmd("inoreabbrev <buffer><expr> atstart v:lua.lazyvim_python_atstart_expand()")
  end,
})
