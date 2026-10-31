-- neotest はプロジェクト全体から test_*.py を探すため、
-- 仮想環境（pyvenv.cfg / conda-meta を持つディレクトリ）の中のライブラリのテストまで拾って重くなる
local skip_dirs = {
  [".git"] = true,
  ["node_modules"] = true,
  ["__pycache__"] = true,
  ["site-packages"] = true,
  [".mypy_cache"] = true,
  [".pytest_cache"] = true,
}

return {
  "nvim-neotest/neotest",
  optional = true,
  opts = {
    discovery = {
      filter_dir = function(name, rel_path, root)
        if skip_dirs[name] then
          return false
        end
        local dir = root .. "/" .. rel_path
        return not (vim.uv.fs_stat(dir .. "/pyvenv.cfg") or vim.uv.fs_stat(dir .. "/conda-meta"))
      end,
    },
  },
}
