-- local pokemon = {
--   "bulbasaur",
--   "charmander",
--   "dratini",
--   "eevee",
--   "growlithe",
--   "mew",
--   "mimikyu",
--   "pachirisu",
--   "pancham",
--   "pichu",
--   "pikachu",
--   "piplup",
--   "psyduck",
--   "shaymin",
--   "skitty",
--   "squirtle",
--   "togepi",
--   "torchic",
--   "yamper",
-- }
local pokemon = {
  "snivy",
  "tepig",
  "oshawott",
  "victini",
  "lilligant",
  "darmanitan",
  "zoroark",
  "chandelure",
  "haxorus",
  "bisharp",
  "hydreigon",
  "volcarona",
  "reshiram",
  "zekrom",
  "kyurem",
  "keldeo",
  "meloetta",
  "genesect",
  "emolga",
}
math.randomseed(os.time())
local chosen = pokemon[math.random(#pokemon)]

return {
  notifier = { enabled = true },
  "snacks.nvim",
  opts = {
    dashboard = {
      sections = vim.fn.executable("pokeget-rs") == 1
          and {
            {
              section = "terminal",
              cmd = "pokeget-rs --hide-name " .. chosen,
              height = 14,
              padding = 1,
            },
            { section = "keys", gap = 1, padding = 1 },
            { section = "startup" },
          }
        or {
          {
            text = [[
        ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
        ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z    
        ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z       
        ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z         
        ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║           
        ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝           
 ]],
            padding = 1,
          },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
    },
  },
}
