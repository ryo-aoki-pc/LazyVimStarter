// ibus の global engine が外から変わったとき (Neovim の IME 連携 lua/config/ime.lua が busctl で
// 切り替えたときなど)、GNOME Shell の「今の入力ソース」を実際の engine に合わせる。
//
// なぜ要るか:
//  - GNOME Shell は ibus の GlobalEngineChanged を受けても、上部バーの表示と Super+Space の順番 (MRU) を
//    更新しない。ui/status/keyboard.js の InputSourceManager は、自分で activateInputSource() したときだけ
//    今の入力ソースを書き換え、misc/ibusManager.js の _engineChanged() は engine の名前を控えるだけ
//    (GNOME Shell 49.4 で確認)。
//  - そのため Neovim がモードに合わせて engine を切り替えると、上部バーは古い入力ソースのままになり、
//    Super+Space は古い認識から「次」を選ぶので一手ぶん空振りする。
//
// 合わせ方:
//  - activateInputSource() は呼ばない。キーボードを一時的に掴む (holdKeyboard) ので、端末にフォーカスの
//    出入り (FocusLost / FocusGained) が届き、engine も設定し直してしまう。
//  - 代わりに InputSourceManager の _currentInputSourceChanged() (内部の関数) で、今の入力ソース・上部バーの
//    表示・MRU の順番だけを更新する。engine とキー配列には触れない (anthy のキー配列は "default" で、
//    入力ソースを切り替えても配列は変わらない)。
//  - 内部の関数なので、無ければ何もしない (GNOME Shell を上げて消えたら、上部バーがずれるだけに戻る)。
//  - GNOME Shell 自身の切り替え (Super+Space) では、シグナルが届く前に今の入力ソースが更新済みなので
//    何もしない。ibus は同じ engine を設定し直してもシグナルを出さない (実測) ので、行き来も起きない。
//  - パスワード欄にいる間 (_disableIBus) は、GNOME Shell が入力ソースを退避して xkb に切り替えているので
//    手を出さない。

import GLib from 'gi://GLib';
import IBus from 'gi://IBus';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Keyboard from 'resource:///org/gnome/shell/ui/status/keyboard.js';

// 検証用: IBUS_ENGINE_FOLLOW_DEBUG があれば、合わせるたびにログを出す (普段は出さない)
const DEBUG = GLib.getenv('IBUS_ENGINE_FOLLOW_DEBUG') !== null;

// 入力ソースが ibus の engine 名に当たるか。xkb の入力ソースは "xkb:<配列>:<変種>:<言語>" の配列と変種で
// 比べる (言語は GNOME Shell が xkb の情報から決めるので見ない)。
function matches(source, engine) {
    if (source.type === Keyboard.INPUT_SOURCE_TYPE_IBUS)
        return source.id === engine;
    if (source.type === Keyboard.INPUT_SOURCE_TYPE_XKB && engine.startsWith('xkb:')) {
        const [, layout = '', variant = ''] = engine.split(':');
        const [id, idVariant = ''] = source.id.split('+');
        return id === layout && idVariant === variant;
    }
    return false;
}

export default class IbusEngineFollowExtension extends Extension {
    enable() {
        this._bus = IBus.Bus.new_async();
        // GlobalEngineChanged を受け取るのに要る (misc/ibusManager.js と同じ)
        this._bus.set_watch_ibus_signal(true);
        this._engineChangedId = this._bus.connect('global-engine-changed',
            (_bus, engine) => this._follow(engine));
        if (DEBUG)
            console.log('ibus-engine-follow: enabled');
    }

    disable() {
        if (this._bus) {
            this._bus.disconnect(this._engineChangedId);
            this._bus.set_watch_ibus_signal(false);
            this._bus = null;
        }
    }

    _follow(engine) {
        const manager = Keyboard.getInputSourceManager();
        if (typeof manager._currentInputSourceChanged !== 'function' || manager._disableIBus)
            return;
        const current = manager.currentSource;
        if (current && matches(current, engine))
            return;
        const target = Object.values(manager.inputSources).find(s => matches(s, engine));
        if (!target)
            return;
        manager._currentInputSourceChanged(target);
        if (DEBUG)
            console.log(`ibus-engine-follow: ${engine} -> ${manager.currentSource?.id}`);
    }
}
