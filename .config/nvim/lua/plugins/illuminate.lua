-- koehler など illuminate 用の色を持たない colorscheme では既定の下線だけになるので、
-- snacks words のときと同じ LSP 参照ハイライトの色を使う（colorscheme を変えても付け直す）
return {
  "RRethy/vim-illuminate",
  optional = true,
  init = function()
    local function link()
      for _, kind in ipairs({ "Text", "Read", "Write" }) do
        vim.api.nvim_set_hl(0, "IlluminatedWord" .. kind, { link = "LspReference" .. kind })
      end
    end
    link()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("illuminate_link_lsp_reference", { clear = true }),
      callback = link,
    })
  end,
}
