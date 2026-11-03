-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

-- AI に場所を伝えるため「ファイルパス:行番号」をクリップボードにコピーする
-- パスは git のルートから。ビジュアル選択中なら「:開始-終了」。<leader>fY はコードも一緒にコピー
local function copy_code_ref(with_code)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then
    vim.notify("ファイルではないのでコピーできません", vim.log.levels.WARN)
    return
  end
  local path = vim.fs.relpath(LazyVim.root.git(), file) or vim.fn.fnamemodify(file, ":~:.")
  local first, last = vim.fn.line("."), vim.fn.line(".")
  if vim.fn.mode():match("^[vV\22]") then
    first, last = math.min(vim.fn.line("v"), last), math.max(vim.fn.line("v"), last)
    vim.cmd("normal! \27") -- ビジュアル選択を抜ける
  end
  local ref = path .. ":" .. first .. (last ~= first and ("-" .. last) or "")
  local text = ref
  if with_code then
    local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
    text = ref .. "\n```" .. vim.bo.filetype .. "\n" .. table.concat(lines, "\n") .. "\n```"
  end
  vim.fn.setreg("+", text)
  vim.notify("コピーしました: " .. ref)
end
vim.keymap.set({ "n", "x" }, "<leader>fy", function()
  copy_code_ref(false)
end, { desc = "Copy path:line (for AI)" })
vim.keymap.set({ "n", "x" }, "<leader>fY", function()
  copy_code_ref(true)
end, { desc = "Copy path:line + code (for AI)" })

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

-- Treat :wq like :wqall so all modified buffers are saved before quitting.
vim.cmd([[
  cnoreabbrev <expr> wq getcmdtype() == ':' && getcmdline() ==# 'wq' ? 'wqall' : 'wq'
  cnoreabbrev <expr> Wq getcmdtype() == ':' && getcmdline() ==# 'Wq' ? 'wqall' : 'Wq'
  cnoreabbrev <expr> WQ getcmdtype() == ':' && getcmdline() ==# 'WQ' ? 'wqall' : 'WQ'
]])
