-- CSV / TSV を列をそろえた表として表示する（ファイルの中身は変えない）
-- 開くと自動で表表示になる。<leader>uv で元の表示と切り替え。
-- 1.5MB を超える CSV は snacks の bigfile 扱いになり、自動では表表示にしない（重くなるため）
return {
  "hat0uma/csvview.nvim",
  cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("csvview_auto_enable", { clear = true }),
      pattern = { "csv", "tsv" },
      callback = function(ev)
        vim.keymap.set("n", "<leader>uv", "<cmd>CsvViewToggle<cr>", { buffer = ev.buf, desc = "Toggle CSV View" })
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            vim.api.nvim_buf_call(ev.buf, function()
              vim.cmd("CsvViewEnable")
            end)
          end
        end)
      end,
    })
  end,
  opts = {
    view = {
      display_mode = "border", -- 列の区切りを │ で表示する
    },
    keymaps = {
      -- Tab / Shift-Tab で次・前の列へ移動、if / af で 1 マス分を選択（例: cif でマスの中身を書き換え）
      jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
      jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
      textobject_field_inner = { "if", mode = { "o", "x" } },
      textobject_field_outer = { "af", mode = { "o", "x" } },
    },
  },
}
