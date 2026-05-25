return {
  "levouh/tint.nvim",
  config = function()
    require("tint").setup({
      tint = -45,
      saturation = 0.6,
    })
  end,
}
