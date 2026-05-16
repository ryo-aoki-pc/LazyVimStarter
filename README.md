# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

## SKK

- `vim-skk/skkeleton` is configured through `denops.vim`, so `deno` must be available in `PATH`.
- Run `:SkkDownloadDictionary` once to install the default dictionary set into `stdpath("data") .. "/skk"`.
- The default set is `SKK-JISYO.L`, `SKK-JISYO.jinmei`, `SKK-JISYO.geo`, `SKK-JISYO.station`, `SKK-JISYO.propernoun`, `SKK-JISYO.fullname`, `SKK-JISYO.assoc`, `SKK-JISYO.zipcode`, `SKK-JISYO.office.zipcode`, `SKK-JISYO.JIS2`, `SKK-JISYO.JIS3_4`, and `SKK-JISYO.JIS2004`.
- Additional or repeated downloads can be requested with `:SkkDownloadDictionary SKK-JISYO.fullname`, `assoc`, `zipcode`, `office.zipcode`, `JIS2`, `JIS3_4`, or `JIS2004`.
- The helper also extracts `SKK-JISYO.zipcode` and `SKK-JISYO.office.zipcode` from `zipcode.tar.gz`; other archive-based dictionaries such as `SKK-JISYO.edict.tar.gz` are still manual installs.
- Dictionary target paths can be listed with `:SkkDictionaryPath`.
- Toggle SKK with `<C-j>` in Insert mode and command-line mode.
- Candidate ranking is stored in `stdpath("state") .. "/skkeleton/rank.json"`.
