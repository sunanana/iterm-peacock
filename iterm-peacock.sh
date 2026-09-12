# iterm-peacock — 最寄りの .peacock に合わせて iTerm2 の配色・タブ色・バッジを切り替えるシェルフック
#
# Zsh:   プラグインのエントリポイント（iterm-peacock.plugin.zsh）を読み込む。
#        フックの登録と CLI の PATH 追加はそちらで行う。
#
# Bash:  source iterm-peacock.sh
#        PROMPT_COMMAND="_peacock_apply${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
#
# CLI とプラグインからも source され、.peacock の探索・解釈はここに集約している。
# macOS 標準の bash 3.2 と zsh の両方で動く書き方に限定すること。
# プロンプト毎に実行されるため、解釈の処理では外部コマンドやサブシェルを増やさないこと。
#
# 対応キーは「ディレクトリを出たときに iTerm2 の元の状態へ戻せるもの」に限っている。
# 太字・リンク・下線・カーソル上の文字色は、iTerm2 側に元へ戻すエスケープシーケンスがないため対象外。

# 直前に適用した設定（key=value の改行区切り）。変化がなければ何も出力しないためのキャッシュ
_PEACOCK_LAST=""

# $PWD から親へ辿り、最初に見つかった .peacock のパスを出力する
_peacock_find() {
  local dir="$PWD"
  while [[ "$dir" != / && -n "$dir" ]]; do
    [[ -f "$dir/.peacock" ]] && printf '%s' "$dir/.peacock" && return 0
    dir="${dir%/*}"
  done
  return 1
}

_peacock_is_color_key() {
  case "$1" in
    background|foreground|tab|cursor|selection|selection-text) return 0 ;;
    black|red|green|yellow|blue|magenta|cyan|white) return 0 ;;
    bright-black|bright-red|bright-green|bright-yellow) return 0 ;;
    bright-blue|bright-magenta|bright-cyan|bright-white) return 0 ;;
  esac
  return 1
}

# ANSI 16色のキー名をパレット番号にし、呼び出し側の変数 index に入れる（サブシェルを避けるため）
_peacock_ansi_index() {
  case "$1" in
    black) index=0 ;; red) index=1 ;; green) index=2 ;; yellow) index=3 ;;
    blue) index=4 ;; magenta) index=5 ;; cyan) index=6 ;; white) index=7 ;;
    bright-black) index=8 ;; bright-red) index=9 ;; bright-green) index=10 ;; bright-yellow) index=11 ;;
    bright-blue) index=12 ;; bright-magenta) index=13 ;; bright-cyan) index=14 ;; bright-white) index=15 ;;
    *) return 1 ;;
  esac
}

# 色の表記ゆれ（# の有無、大文字、3桁の短縮形）を rrggbb に揃え、呼び出し側の変数 hex に入れる。
# サブシェルを避けるため、結果は出力せず動的スコープで返している。色でなければ失敗する
_peacock_normalize() {
  local v="${1#\#}"
  if [[ "$v" =~ ^[0-9a-fA-F]{3}$ ]]; then
    v="${v:0:1}${v:0:1}${v:1:1}${v:1:1}${v:2:1}${v:2:1}"
  fi
  [[ "$v" =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  v="${v//A/a}"; v="${v//B/b}"; v="${v//C/c}"; v="${v//D/d}"; v="${v//E/e}"; v="${v//F/f}"
  hex="$v"
}

# .peacock の1行を解釈し、呼び出し側の変数 key / value に入れる。対応キーの正しい値でなければ失敗する。
#   - `key=value` 形式。= の前後の空白は無視する
#   - 色だけを書いた行（#rrggbb）は background として扱う
#   - # で始まる行（色だけの行を除く）と、「空白 + # + 空白」以降はコメント
_peacock_parse_line() {
  local line="$1" hex
  # zsh の EXTENDED_GLOB では素の # がパターン演算子になるためエスケープしている
  line="${line%%[[:space:]]\#[[:space:]]*}"
  line="${line%[[:space:]]\#}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -n "$line" ]] || return 1

  if [[ "$line" == *=* ]]; then
    key="${line%%=*}"
    value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
  else
    key=background
    value="$line"
  fi

  case "$key" in
    badge)
      [[ -n "$value" ]] || return 1
      ;;
    cursor-guide)
      case "$value" in
        yes|true|on) value=yes ;;
        no|false|off) value=no ;;
        *) return 1 ;;
      esac
      ;;
    *)
      _peacock_is_color_key "$key" || return 1
      _peacock_normalize "$value" || return 1
      value="#$hex"
      ;;
  esac
}

# .peacock を解釈し、有効な設定を key=value の改行区切りで出力する。同じキーは最初の行を使う
_peacock_read() {
  local file="$1" raw key value seen=" "
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    _peacock_parse_line "$raw" || continue
    [[ "$seen" == *" $key "* ]] && continue
    seen="$seen$key "
    printf '%s=%s\n' "$key" "$value"
  done < "$file"
}

# 最寄りの .peacock から、実際に適用する設定を出力する
_peacock_resolve() {
  local file config=""
  if file="$(_peacock_find)"; then
    config="$(_peacock_read "$file")"
  fi
  _peacock_finalize "$config"
}

# .peacock の設定（_peacock_read の出力）に、ファイル外の規則を足して適用する設定にする。
#   - tab の指定がなければ background と同じ色にする
_peacock_finalize() {
  local config="$1" line bg="" out=""
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" == background=* ]] && bg="${line#background=}"
    out="$out$line"$'\n'
  done <<< "$config"

  if [[ -n "$bg" && $'\n'"$out" != *$'\n'tab=* ]]; then
    out="${out}tab=$bg"$'\n'
  fi
  printf '%s' "$out"
}

_peacock_osc_rgb() {
  local code="$1" hex="${2#\#}"
  printf '\e]%s;rgb:%s/%s/%s\a' "$code" "${hex:0:2}" "${hex:2:2}" "${hex:4:2}"
}

_peacock_set() {
  local key="$1" value="$2" hex="${2#\#}" index
  case "$key" in
    background) _peacock_osc_rgb 11 "$value" ;;
    foreground) _peacock_osc_rgb 10 "$value" ;;
    cursor) _peacock_osc_rgb 12 "$value" ;;
    selection) _peacock_osc_rgb 17 "$value" ;;
    selection-text) _peacock_osc_rgb 19 "$value" ;;
    tab)
      # iTerm2 独自のタブ色（VS Code Peacock のタイトルバー着色に相当）
      printf '\e]6;1;bg;red;brightness;%d\a' "$((16#${hex:0:2}))"
      printf '\e]6;1;bg;green;brightness;%d\a' "$((16#${hex:2:2}))"
      printf '\e]6;1;bg;blue;brightness;%d\a' "$((16#${hex:4:2}))"
      ;;
    badge)
      printf '\e]1337;SetBadgeFormat=%s\a' "$(printf '%s' "$value" | base64 | tr -d '\n')"
      ;;
    cursor-guide)
      printf '\e]1337;HighlightCursorLine=%s\a' "$value"
      ;;
    *)
      _peacock_ansi_index "$key"
      _peacock_osc_rgb "4;$index" "$value"
      ;;
  esac
}

# iTerm2 は OSC 110/111/112/117/119/104 でプロファイルの色に戻す。
# バッジとカーソルガイドはプロファイルの値を取得できないため、空・非表示に戻す
_peacock_unset() {
  local index
  case "$1" in
    background) printf '\e]111\a' ;;
    foreground) printf '\e]110\a' ;;
    cursor) printf '\e]112\a' ;;
    selection) printf '\e]117\a' ;;
    selection-text) printf '\e]119\a' ;;
    tab) printf '\e]6;1;bg;*;default\a' ;;
    badge) printf '\e]1337;SetBadgeFormat=\a' ;;
    cursor-guide) printf '\e]1337;HighlightCursorLine=no\a' ;;
    *) _peacock_ansi_index "$1"; printf '\e]104;%s\a' "$index" ;;
  esac
}

# 前回の設定から今回の設定へ切り替える。なくなったキーは元に戻し、値が変わったキーと新しいキーだけを設定する。
# iTerm2 は色の変更ごとにプロファイルを書き換えるため、変わっていないキーは送らない
_peacock_render() {
  local old="$1" new="$2" line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ $'\n'"$new" == *$'\n'"${line%%=*}="* ]] || _peacock_unset "${line%%=*}"
  done <<< "$old"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ $'\n'"$old"$'\n' == *$'\n'"$line"$'\n'* ]] && continue
    _peacock_set "${line%%=*}" "${line#*=}"
  done <<< "$new"
}

_peacock_apply() {
  local config
  config="$(_peacock_resolve)"

  [[ "$config" == "$_PEACOCK_LAST" ]] && return 0
  _peacock_render "$_PEACOCK_LAST" "$config"
  _PEACOCK_LAST="$config"
}
