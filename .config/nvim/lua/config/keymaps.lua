-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- register to WhichKey
if require("lazyvim.util").has("which-key.nvim") then
  local wk = require("which-key")

  wk.add({
    -- Compile & execute code
    {
      "<leader>r",
      function()
        if type(RunCode) == "function" then
          RunCode()
        else
          -- RunCodeがVimコマンドとして定義されている場合はこちらを使います
          -- vim.cmd("RunCode")
          vim.notify("RunCode function is not defined", vim.log.levels.WARN)
        end
      end,
      desc = "Run Code",
    },
    -- Starter
    {
      "<leader>uS",
      function()
        if type(Snacks) == "table" and Snacks.dashboard then
          Snacks.dashboard()
        else
          vim.notify("Snacks.dashboard is not available", vim.log.levels.WARN)
        end
      end,
      desc = "Open Dashboard",
    },
    -- CodeCompanion group
    { "<leader>a", group = "CodeCompanion", icon = "", mode = { "n", "v" } },
  })
end

-- Iwamoto custom (map :Wq to :wq, :WQ to :wq)
vim.cmd([[
  cnoreabbrev Wq wq
  cnoreabbrev WQ wq
]])
