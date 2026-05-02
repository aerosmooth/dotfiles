return {
  "snacks.nvim",
  opts = function(_, opts)
    local doraemon_cmd = vim.fn.stdpath("config") .. "/scripts/doraemon_dashboard.sh"

    opts = opts or {}
    opts.notifier = { enabled = true }
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.sections = {
      {
        section = "terminal",
        cmd = doraemon_cmd,
        height = 28,
        padding = 1,
      },
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }

    return opts
  end,
}
