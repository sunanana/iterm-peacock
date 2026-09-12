# iterm-peacock の zsh プラグインのエントリポイント。
# プラグインマネージャや `source` から読み込まれ、
# フックの読み込み・precmd への登録・CLI の PATH 追加までを行う。
# 何度 source されても登録が重複しないようにしている。

# source 元の相対パスやシンボリックリンクに左右されないよう、このファイルの実体の場所を使う
_PEACOCK_ROOT="${${(%):-%x}:A:h}"

source "$_PEACOCK_ROOT/iterm-peacock.sh"

autoload -Uz add-zsh-hook
add-zsh-hook precmd _peacock_apply

(( ${path[(Ie)$_PEACOCK_ROOT/bin]} )) || path+=("$_PEACOCK_ROOT/bin")
