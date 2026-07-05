return {
  {
    "kana/vim-operator-user",
  },
  {
    "tpope/vim-repeat",
  },
  {
    "mopp/vim-operator-convert-case",
    dependencies = {
      "kana/vim-operator-user",
      "tpope/vim-repeat",
    },
    keys = {
      { "<leader>Cls", "<Plug>(operator-convert-case-lower-snake)", mode = "n", desc = "Convert motion to lower_snake_case" },
      { "<leader>CuS", "<Plug>(operator-convert-case-upper-snake)", mode = "n", desc = "Convert motion to UPPER_SNAKE_CASE" },
      { "<leader>Clc", "<Plug>(operator-convert-case-lower-camel)", mode = "n", desc = "Convert motion to lowerCamelCase" },
      { "<leader>CuC", "<Plug>(operator-convert-case-upper-camel)", mode = "n", desc = "Convert motion to UpperCamelCase" },
      { "<leader>Ct", "<Plug>(operator-convert-case-toggle-upper-lower)", mode = "n", desc = "Toggle word case" },
      { "<leader>Cl", "<Plug>(operator-convert-case-loop)", mode = "n", desc = "Loop word case" },
      { "<leader>Cc", "<Plug>(operator-convert-case-convert)", mode = "n", desc = "Choose word case" },
    },
  },
}

