# LazyVimStarter README の検証記録

以下は既存文書から移した記録。本文の「本書」「この文書」と手順番号は、記録元の手順書を指す。新しく検証した記録ではない。

導入手順は [README](../../README.md) から参照する。

## 実施結果の要約

2026-10-06 に新規 AlmaLinux 10.2 VM で[CLI の導入と整形](setup.md#付録-新規-almalinux-102-vm-での-cli-導入整形の再検証2026-10-06)、別の GNOME VM で[通常 GUI と IBus のキー](setup.md#付録-現行手順を別のクリーン-vm-の-gnome-で再検証-2026-10-06)を再検証した。遅い VM の Markdown 整形の待ち時間も修正して再確認した。物理キーやすべての任意節を一括して確認した記録ではない。

## IME 連携の観測

- **Neovim の中では `<C-j>` を使うこと**: gnome-shell は ibus の global engine が外部から
  変わっても自分の内部状態を更新しない (gsettings の `current` を書いても追従しないことを
  実測で確認済み)。そのため nvim がモードに応じてエンジンを切り替えた後に Super+Space を
  押すと、gnome-shell は古い認識を基準に「次のソース」を選ぶので、一手ぶん空振りすることがある
  (もう一度押せば揃う)。`<C-j>` は nvim が直接切り替えるので常に意図どおり動く。
  なお nvim を抜けた時点では上記の復帰処理で必ず整合が取れるため、OS 側の切替が
  壊れたままになることはない。
  GNOME 49 では、[docs/setup.md の上部バーの節](../setup.md#gnome-の上部バーを-ime-連携に合わせる-任意)で
  GNOME Shell の拡張 (`gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com`) を入れると、上部バーと
  Super+Space の順番が nvim の切り替えに付いてくるので、このずれは起きない。
