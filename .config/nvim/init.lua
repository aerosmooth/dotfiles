-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
-- require("lazy").setup("plugins")
require("custom.functions")

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    -- ["+"] = function()
    --   return {}
    -- end,
    -- ["*"] = function()
    --   return {}
    -- end,
  },
}

vim.opt.clipboard = "unnamedplus"
