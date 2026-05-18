local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node

return {
  s("atstart", {
    t({
      "import sys",
      "",
      "",
      "def read_input():",
      "    input_data = sys.stdin.read().split()",
      "",
      "    return ",
    }),
    i(1),
    t({
      "",
      "",
      "def solve():",
      "    ",
    }),
    i(2),
    t(" = read_input()"),
    t({
      "",
      "    ",
    }),
    i(3),
    t({
      "",
      "",
      "if __name__ == \"__main__\":",
      "    solve()",
    }),
  }),
}
