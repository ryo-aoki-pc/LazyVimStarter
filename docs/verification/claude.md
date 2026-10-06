# 開発ガイドの検証記録

以下は既存文書から移した記録。本文の「本書」「この文書」と手順番号は、記録元の手順書を指す。新しく検証した記録ではない。

以下は既存 CLAUDE.md にあった実施範囲の記録。操作は [導入手順](../setup.md)、詳細は [導入の検証記録](setup.md) を参照する。

  - 2026-10-06 は新規 AlmaLinux 10.2 x86_64 VM に ae7f049 を新規導入し、CLI の前提・lock 38 個・Mason 11 個・パーサー 30 個・検索・保存を確認した (setup.md の CLI 付録)。遅い VM で Markdown 整形が 3 秒を超えたため、Markdown / MDX 限定で 10 秒の上限に修正して再実行し、GLFM 記法の保持・他のファイル形式の設定も確認した。別の新規 GNOME VM で手順 13〜19 も実行し、入力ソースと Anthy キー保持・通常 GUI・Mason11 / パーサー30・Migemo / Tab・修正後の保存・IBus Ctrl+J / Esc と検索 sticky・アイコンを実 evdev keycode と PNG で確認した (setup.md の GUI 付録)。物理キー・上部バー拡張・画像貼り付け等は今回未実施
  - 状態の要約 (補足の状態行を変えたらここも直す): AlmaLinux 10 は x86_64 のコンテナで、文書のブロックを
    そのまま貼って通した (aarch64 は未確認。検証した設定は PR #26 より前)。GNOME の実機では、導入済みの PC で
    置き場所を差し替えて導入の手順 16〜19 と取り込みの手順 1 (変更がある状態) を通した (手順 1〜15 は
    状態の確認だけ。パーサーとハイライト、カーソル直下と検索中の `あ` / `A`、img-clip、GitLab の近似表示と Firefox は確かめ、
    アイコンの字形と Firefox の表示は利用者が目で確かめた)。その後、利用者の本物のキーで、手順 15 が Homebrew の
    `gsettings` のせいで dconf に入っておらず日本語のときの `<C-j>` が Anthy に食われていたことが分かり、`/usr/bin/gsettings`
    で入れ直して直った。上部バーの拡張は画面の無い gnome-shell 49.4 で確かめ、本物のログイン・本物の Super+Space・
    トークンの節は未確認。Windows 11 は実機 (Windows 11 Pro) で、設定とデータの置き場所を
    差し替えて Windows PowerShell 5.1 に渡して通した (IME の切り替えはモックの zenhan で確かめた。Neovide 0.16.2 の画面は、
    未確定文字列のハンドラを呼ぶ形で確かめた。検索中の表示は、手順を通した後に Neovide と端末で個別に確かめた)。
    2026-09-30 に、scoop も Git for Windows も PATH に無い状態から Windows 導入の手順 1〜11・更新の手順 2・ロールバックの手順 5〜7 を
    通し (scoop は一時的な場所に入れ、scoop が書くユーザーの環境変数は HKCU の差し替えで受けた)、利用者の離席中に本物の IME
    (`SendInput`) と本物の zenhan で Neovide と WezTerm を確かめた。flash の `s`・フォーカスが戻ったときの表示・取り込みの手順 2 の
    lock の書き直しも Windows で確かめ、scoop の git (`core.autocrlf=true`) で `lazy-lock.json` が `M` になり続ける不具合を
    `.gitattributes` で直した (VC++ のランタイムの無い Windows 11 は未確認)。
    markdown-preview.nvim と markdown-toc を外し GitLab プレビュー・img-clip.nvim・GLFM のスニペットを足した変更は、
    Windows 11 の実機で置き場所を差し替え、模擬の GitLab API と headless の Edge で確かめた。本物のクリップボードの
    画像・既定のブラウザ・トークンの節の Windows の手順 (模擬のトークン)・gitlab.com の 401 も確かめ、本物の GitLab で
    表示できることはマージの後に利用者が確かめた (本物の GitLab での記法ごとの見え方と、トークンの節の AlmaLinux の手順は未確認)。
    SSH 越しのクリップボード (OSC 52) は、コンテナで tmux を手元の端末の代わりにして確かめた後、AlmaLinux 10 の実機で
    WezTerm の nightly (画面の無い mutter の上) から ssh し、SSH の節のブロックをそのまま貼って通した。2026-09-30 に、Windows の
    WezTerm の nightly (Windows の OpenSSH と Git for Windows の ssh) と Windows Terminal から、WSL の AlmaLinux 10.2 に立てた sshd
    (自分のユーザーのまま・PAM を通す root の 2 通り) に ssh して、同じブロックで通した (GNOME にログインした画面、実機の
    AlmaLinux 10 の sshd.service は未確認)。取り込みの手順 1 は AlmaLinux 10 の実機で、使っている設定に対して行った
    (増えたプラグインを起動時に入れると lock が書き直され、`checkout` して `restore` し直すと揃うことを含む)
