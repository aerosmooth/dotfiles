return {
  "TimUntersberger/neogit",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>gs", "<cmd>Neogit<CR>", desc = "Open Neogit" },
  },
  config = function()
    require("neogit").setup({})
  end,
}
