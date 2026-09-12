# iterm-peacock の zsh プラグインのエントリポイント。
# プラグインマネージャや `source` から読み込まれ、
# フックの読み込み・precmd / preexec への登録・CLI の PATH 追加までを行う。
# 何度 source されても登録が重複しないようにしている。

# source 元の相対パスやシンボリックリンクに左右されないよう、このファイルの実体の場所を使う
_PEACOCK_ROOT="${${(%):-%x}:A:h}"

source "$_PEACOCK_ROOT/iterm-peacock.sh"

# 打ったコマンドに設定ファイルがあれば、その実行の間だけ配色を切り替える。
# 元に戻すのは precmd が担うため、ここに終了を見張る処理はない。
# $2 はエイリアスを展開した後のコマンド行で、${(z)...} でシェルと同じ語分割ができる。
# 引用符は (Q) で外し、bash のラッパーや CLI の test が受け取る引数と同じ語にする
_peacock_preexec() {
  local -a words
  words=(${(Q)${(z)${2-}}})
  (( $#words )) && _peacock_enter "${words[@]}"
  # 当てはまらなかっただけで失敗を返さない（フックの戻り値をシェルに持ち込まない）
  return 0
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _peacock_precmd
[[ "${PEACOCK_COMMANDS:-1}" == 0 ]] || add-zsh-hook preexec _peacock_preexec

(( ${path[(Ie)$_PEACOCK_ROOT/bin]} )) || path+=("$_PEACOCK_ROOT/bin")
