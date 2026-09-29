-- クリップボードの画像 (スクリーンショットなど) を Markdown に貼る: img-clip.nvim
-- <leader>ci で画像を「.md と同じディレクトリの assets/」にファイルとして保存し、![](assets/….png) を挿入する。
-- 相対リンクなので、そのまま push すれば GitLab の表示でも画像が出る (GitLab プレビューも同じ規則で解決する)。
-- 取得の手段: Windows は PowerShell (System.Windows.Forms.Clipboard)、Linux は wl-paste (wl-clipboard) か xclip。
-- Windows で 'shell' が pwsh / powershell のとき、img-clip は PowerShell のコマンドを 'shell' 経由の
-- vim.fn.system() でそのまま実行する。lua/config/options.lua の shellcmdflag (UTF-8 の前置き) の後ろに
-- 連結されて動く。Clipboard に要る STA は、5.1 でも 7 でも既定になっている。
return {
  "HakonHarnes/img-clip.nvim",
  cmd = { "PasteImage", "ImgClipDebug", "ImgClipConfig" },
  keys = {
    -- <leader>p は LazyVim の yanky extra が使うので、code グループの <leader>ci (insert image) にする
    { "<leader>ci", "<cmd>PasteImage<cr>", ft = "markdown", desc = "画像を貼り付け (クリップボード)" },
  },
  opts = {
    default = {
      -- 保存先 (dir_path の既定は "assets") を、Neovim のカレントディレクトリではなく .md の場所から決める。
      -- 挿入するリンクも .md からの相対になり、GitLab がそのまま解決できる。
      relative_to_current_file = true,
      -- ドラッグ & ドロップ (貼り付けた画像のパスや URL を拾って、コピーやダウンロードをする) は使わない。
      -- img-clip は読み込まれると vim.paste を上書きするので、有効のままだと以後の貼り付けがすべて
      -- 画像の判定を通る (URL なら curl でダウンロードしに行く)。無効にすれば、ふつうの貼り付けに戻す。
      drag_and_drop = { enabled = false },
    },
  },
  config = function(_, opts)
    require("img-clip").setup(opts)
    -- img-clip は設定を引くたびに (上の vim.paste の上書きを通る、すべての貼り付けでも)、
    -- 編集中のファイルから上に向かって .img-clip.lua を探し、見つかれば dofile で実行する。
    -- clone してきたリポジトリに置かれた Lua が、貼り付けただけで走ってしまう。この設定では
    -- プロジェクトごとの設定ファイルは使わないので、常に setup() の設定を返すように差し替える。
    -- img-clip の内部関数なので、名前が変わったら警告を出す (黙って守りが外れないように)。
    local config = require("img-clip.config")
    if type(config.get_config) ~= "function" then
      vim.notify(
        "img-clip.config.get_config が見つからない。.img-clip.lua を読み込まない設定が効いていない",
        vim.log.levels.WARN
      )
      return
    end
    config.get_config = function()
      config.config_file = "Default"
      return config.opts
    end
  end,
}
