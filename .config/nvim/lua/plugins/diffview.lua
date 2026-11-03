-- AI が書き換えたコードの差分を、ファイル一覧つきの左右分割で確認する
-- （Neogit からも使われる。Neogit 画面で d → 差分を diffview で開く）
local function diffview_is_open()
  return next(require("diffview.lib").views) ~= nil
end

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    {
      "<leader>gv",
      function()
        vim.cmd(diffview_is_open() and "DiffviewClose" or "DiffviewOpen")
      end,
      desc = "Diffview (uncommitted changes)",
    },
    {
      "<leader>gV",
      function()
        vim.ui.input({ prompt = "Compare with (e.g. HEAD~1, main): ", default = "HEAD~1" }, function(ref)
          if ref and vim.trim(ref) ~= "" then
            vim.cmd("DiffviewOpen " .. vim.trim(ref))
          end
        end)
      end,
      desc = "Diffview (compare with ref)",
    },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History (current file)" },
  },
  opts = {
    enhanced_diff_hl = true, -- 削除・追加・変更の色を区別しやすくする
  },
}
