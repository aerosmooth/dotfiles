return {
  "snacks.nvim",
  opts = function()
    -- pokemon-colorscriptsが実行可能かチェック
    if vim.fn.executable("pokemon-colorscripts") ~= 1 then
      -- なければLAZYVIMのロゴを表示
      return {
        notifier = { enabled = true },
        dashboard = {
          sections = {
            {
              text = [[
      ██╗     █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗      Z
      ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║    Z
      ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║  z
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
      }
    end

    -- 色違いにするかどうかのフラグを確率で決める
    -- math.random(25) == 1 なので、1/25 (4%) の確率でtrueになる
    local is_shiny = math.random(2) == 1
    local shiny_flag = is_shiny and "-s" or "" -- trueなら"-s"、falseなら空文字

    -- 表示するポケモンリスト
    local pokemon_list =
      "snivy,tepig,oshawott,victini,lilligant,darmanitan,zoroark,chandelure,haxorus,bisharp,hydreigon,volcarona,reshiram,zekrom,kyurem,keldeo,meloetta,genesect,emolga"

    -- "bulbasaur,charmander,dratini,eevee,growlithe,mew,mimikyu,pachirisu,pancham,pichu,pikachu,piplup,psyduck,shaymin,skitty,squirtle,togepi,torchic,yamper"

    -- 最終的なコマンドを組み立てる
    local cmd = string.format("pokemon-colorscripts --no-title -rn %s %s", pokemon_list, shiny_flag)

    return {
      notifier = { enabled = true },
      dashboard = {
        sections = {
          {
            section = "terminal",
            cmd = cmd,
            height = 16,
            padding = 1,
          },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    }
  end,
}
