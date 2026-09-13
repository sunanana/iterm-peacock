# iterm-peacock の zsh プラグインのエントリポイント。
# プラグインマネージャや `source` から読み込まれ、
# フックの読み込み・precmd / preexec への登録・CLI の PATH 追加までを行う。
# 何度 source されても登録が重複しないようにしている。

# source 元の相対パスやシンボリックリンクに左右されないよう、このファイルの実体の場所を使う
_PEACOCK_ROOT="${${(%):-%x}:A:h}"

source "$_PEACOCK_ROOT/iterm-peacock.sh"

# コマンド行から、設定に当てはまる最初のコマンドを探し、呼び出し側の変数 name / section / target に入れる。
# 当てはまるものがなければ失敗する。配色は変えないため、CLI の cmd check も同じ読み方でコマンド行を検証できる。
# ${(z)...} でシェルと同じ語分割をしたうえで、
#   - 1行を ; && || | |& と括弧でコマンドごとに区切る。
#     preexec と precmd は行に1回ずつなので、行の途中で配色を切り替えることはできない
#   - & で裏に回したコマンドは端末を占有しないため対象にしない
#   - リダイレクト（2>/dev/null など）は演算子と行き先を語から除く
#   - 区切りの判定は引用符を外す前に行い（'&&' は区切りにしない）、
#     渡す語は (Q) で外して、bash のラッパーや CLI の test が受け取る引数と同じにする
_peacock_select_line() {
  setopt localoptions extendedglob
  local -a words
  local token redirect=0
  for token in "${(@z)1}" ';'; do
    if (( redirect )); then
      redirect=0
      continue
    fi
    case "$token" in
      ';'|'&&'|'||'|'|'|'|&'|'('|')'|'{'|'}')
        (( $#words )) && _peacock_lookup "${(@Q)words}" && return 0
        words=()
        ;;
      '&'|'&|'|'&!')
        words=()
        ;;
      *)
        if [[ "$token" == (\&|[0-9]##|)[\<\>][\<\>\&\|\!-]# ]]; then
          redirect=1
        else
          words+=("$token")
        fi
        ;;
    esac
  done
  return 1
}

# 打ったコマンドに設定ファイルがあれば、その実行の間だけ配色を切り替える。
# 元に戻すのは precmd が担うため、ここに終了を見張る処理はない。
# $2 はエイリアスを展開した後のコマンド行
_peacock_preexec() {
  local name section target
  _peacock_select_line "${2-}" && _peacock_activate
  # 当てはまらなかっただけで失敗を返さない（フックの戻り値をシェルに持ち込まない）
  return 0
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _peacock_precmd
[[ "${PEACOCK_COMMANDS:-1}" == 0 ]] || add-zsh-hook preexec _peacock_preexec

(( ${path[(Ie)$_PEACOCK_ROOT/bin]} )) || path+=("$_PEACOCK_ROOT/bin")
