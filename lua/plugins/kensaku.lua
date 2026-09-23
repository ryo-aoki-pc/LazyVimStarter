-- ローマ字のまま日本語をバッファ検索する (Migemo 後継の denops 実装)。
-- 例: /kensaku<CR> が「検索」「けんさく」「ケンサク」等にマッチ。
-- ノーマルモード/コマンドラインでは IME を必ず英数に落とす運用 (lua/config/ime.lua) のため、
-- 「検索のたびに IME を入れ直す」を避けるにはこれが要になる。
return {
  {
    "lambdalisue/vim-kensaku", -- 旧名 kensaku.vim
    event = "VeryLazy",
    -- denops (Deno サーバー) を明示的に依存として持つ。kensaku がこの設定で denops の
    -- 唯一の利用者なので、他の spec に起動を任せる暗黙の結合を作らない。
    -- denops はサーバー起動時に runtimepath を走査して denops プラグインを発見するため、
    -- 依存として同時にロードされれば kensaku は正しく登録される。
    dependencies = { "vim-denops/denops.vim" },
    init = function()
      -- 辞書 (migemo-compact-dict / jsmigemo 形式) は初回クエリ時に自動ダウンロードされる。
      -- キャッシュ先を既定の ~/.cache/kensaku.vim から stdpath("cache") 配下へ寄せる
      -- (Windows でも適切な場所になる)。
      vim.g.kensaku_dictionary_cache = vim.fn.stdpath("cache") .. "/kensaku/migemo-compact-dict"
    end,
  },
  {
    "lambdalisue/vim-kensaku-search", -- 旧名 kensaku-search.vim
    event = "VeryLazy",
    dependencies = { "lambdalisue/vim-kensaku" },
    -- 検索コマンドライン (/ ?) の <CR> で、入力を kensaku の正規表現に置換してから検索を実行する。
    -- getcmdtype() でガードし、: 等の非検索コマンドラインでは素の <CR> にフォールバックする
    -- (<Plug>(kensaku-search-replace) 自体も / ? 以外では空を返す実装だが、: の <CR> まで
    -- plug 経由にしない二重の防御)。プラグイン側に既定マップはないため自前で張る。
    -- 注: remap=true を付けないこと。<Plug> は noremap でも常に展開される (Vim 仕様) 一方、
    -- remap=true だと戻り値末尾の <CR> がこのマッピング自身に再入して再帰する。
    -- expr の Lua コールバックは replace_keycodes が既定で有効なため追加オプション不要。
    -- 既知の制限: 起動直後 (denops 未起動) の検索は失敗し得る (以後は自然回復)。
    -- 初回検索時のみ辞書ダウンロードの待ちが発生する (要ネットワーク、以後はキャッシュ)。
    keys = {
      {
        "<CR>",
        function()
          local cmdtype = vim.fn.getcmdtype()
          if cmdtype == "/" or cmdtype == "?" then
            return "<Plug>(kensaku-search-replace)<CR>"
          end
          return "<CR>"
        end,
        mode = "c",
        expr = true,
        silent = true,
        desc = "Kensaku 検索",
      },
    },
  },
}
