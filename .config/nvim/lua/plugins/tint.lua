return {
  "levouh/tint.nvim",
  config = function()
    local tint = require("tint")
    tint.setup({
      tint = -45,
      saturation = 0.6,
      -- 差分表示（diffview や :diffthis）の左右は、カーソルがない側も暗くしない
      window_ignore_function = function(winid)
        return vim.wo[winid].diff
      end,
    })
    -- 上の除外はカーソルが窓を離れるときにしか効かず、diff になる前に暗くされた窓はそのまま残る。
    -- そこで窓が diff になった時点で元の色に戻す
    vim.api.nvim_create_autocmd("OptionSet", {
      group = vim.api.nvim_create_augroup("tint_untint_diff", { clear = true }),
      pattern = "diff",
      callback = function()
        if vim.v.option_new then
          tint.untint(vim.api.nvim_get_current_win())
        end
      end,
    })
  end,
}
