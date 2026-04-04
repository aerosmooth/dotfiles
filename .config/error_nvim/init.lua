-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("lazy").setup("plugins")
require("luasnip.loaders.from_lua").lazy_load({ paths = "~/.config/nvim/lua/snippets" })
