return {
  "snacks.nvim",
  opts = function(_, opts)
    local dashboard_script = vim.fn.stdpath("config") .. "/scripts/random_dashboard.py"

    local function choose_art()
      local fallback = { index = 0, height = 30, width = 60 }
      local output = vim.fn.systemlist({ dashboard_script, "--sizes" })

      if vim.v.shell_error ~= 0 then
        return fallback
      end

      local sizes = {}
      for _, line in ipairs(output) do
        local index, height, width = line:match("^(%d+)%s+(%d+)%s+(%d+)$")
        if index and height and width then
          sizes[#sizes + 1] = {
            index = tonumber(index),
            height = tonumber(height),
            width = tonumber(width) * 2,
          }
        end
      end

      if #sizes == 0 then
        return fallback
      end

      math.randomseed(os.time() + vim.fn.getpid())
      return sizes[math.random(#sizes)]
    end

    local art = choose_art()

    opts = opts or {}
    opts.notifier = { enabled = true }
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.sections = {
      {
        section = "terminal",
        cmd = vim.fn.shellescape(dashboard_script) .. " --index " .. art.index,
        height = art.height,
        width = art.width,
        ttl = 0,
        padding = 1,
      },
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }

    return opts
  end,
}
