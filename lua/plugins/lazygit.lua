-- <leader>gg (snacks.nvim の lazygit) で e を押したときのエディタを、OS ごとに決める。
-- snacks は lazygit に os.editPreset = "nvim-remote" を渡す (この Neovim でファイルを開き、lazygit を閉じる)。
-- このプリセットのコマンドは POSIX sh の構文 ([ -z "$NVIM" ] && (…) || (…)) だが、Windows の lazygit は
-- コマンドを cmd.exe で実行するので動かない (jesseduffield/lazygit#3467。未解決)。
-- Windows では "nvim" のプリセットにして、lazygit の窓の中に入れ子の Neovim を開く (:q で lazygit に戻る)。
-- editInTerminal は両方の OS で明示する。lazygit の config.yml に editInTerminal があると、その値がプリセットの
-- 判定より優先されるため。snacks は自分の設定ファイルを LG_CONFIG_FILE の最後に足すので、ここの値が勝つ。
local is_win = vim.fn.has("win32") == 1

return {
  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      lazygit = {
        config = {
          os = is_win and {
            editPreset = "nvim",
            -- lazygit を止めて、入れ子の Neovim に端末を渡す (nvim のプリセットの既定と同じ)
            editInTerminal = true,
          } or {
            -- nvim-remote は Neovim の中では lazygit を止めない (プリセットの既定と同じ)。true にすると、
            -- 外側の Neovim にファイルは開くが、lazygit の窓が閉じずに残る
            editInTerminal = false,
          },
        },
      },
    },
  },
}
