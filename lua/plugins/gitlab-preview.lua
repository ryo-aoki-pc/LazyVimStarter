-- GitLab プレビュー (<leader>cp) の配線。実体は lua/config/gitlab_preview/ (説明は init.lua の冒頭)。
-- lazy.nvim の virtual spec にする: 取得も runtimepath への追加もせず、lazy-lock.json にも載らないが、
-- cmd / keys による遅延読み込みは普通のプラグインと同じに効く (初めて使うまで何も読み込まない)。
-- virtual は lazy.nvim の文書に無い機能 (lazy/core/meta.lua と loader.lua で扱っている)。lazy.nvim を
-- 上げて使えなくなったら、lua/plugins/spell.lua と同じく snacks.nvim の spec の keys に相乗りさせる。
local commands = {
  GitLabPreview = {
    "start",
    "GitLab プレビューを開く (動いていれば送り直し、ブラウザも開き直す)",
  },
  GitLabPreviewStop = { "stop", "GitLab プレビューを止める" },
  GitLabPreviewToggle = { "toggle", "GitLab プレビューを切り替える" },
}

return {
  {
    -- 名前は [1] に書く (name だけだと lazy.nvim が "Invalid plugin spec" として捨てる)。
    -- "/" を含まないので、GitHub の URL にもならない
    "gitlab-preview",
    virtual = true,
    cmd = vim.tbl_keys(commands),
    keys = {
      { "<leader>cp", "<cmd>GitLabPreviewToggle<cr>", ft = "markdown", desc = "GitLab プレビュー (切り替え)" },
    },
    -- 自前の spec なので config を書いてよい (LazyVim の spec を上書きするときとは違う)
    config = function()
      for name, def in pairs(commands) do
        vim.api.nvim_create_user_command(name, function()
          require("config.gitlab_preview")[def[1]]()
        end, { desc = def[2] })
      end
    end,
  },
}
