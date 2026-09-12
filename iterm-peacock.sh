# iterm-peacock — 最寄りの .peacock に合わせて iTerm2 の配色・タブ色・バッジを切り替えるシェルフック
#
# Zsh:   プラグインのエントリポイント（iterm-peacock.plugin.zsh）を読み込む。
#        フックの登録と CLI の PATH 追加はそちらで行う。
#
# Bash:  source iterm-peacock.sh
#        PROMPT_COMMAND="_peacock_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
#        _peacock_wrap_commands         # コマンド連動を使う場合だけ
#
# CLI とプラグインからも source され、.peacock の探索・解釈はここに集約している。
# macOS 標準の bash 3.2 と zsh の両方で動く書き方に限定すること。
# プロンプト毎に実行されるため、解釈の処理では外部コマンドやサブシェルを増やさないこと。
#
# 対応キーは「ディレクトリを出たときに iTerm2 の元の状態へ戻せるもの」に限っている。
# 太字・リンク・下線・カーソル上の文字色は、iTerm2 側に元へ戻すエスケープシーケンスがないため対象外。

# 直前に適用した設定（key=value の改行区切り）。変化がなければ何も出力しないためのキャッシュ
_PEACOCK_LAST=""

# 設定を持つコマンドを実行している間だけ入る、コマンド名・当てはまったセクションの番号・バッジの既定値。
# 入っている間はディレクトリの代わりにこれで設定を決める
_PEACOCK_CMD=""
_PEACOCK_SECTION=""
_PEACOCK_TARGET=""

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

# 行の前後の空白と行末コメントを取り除き、呼び出し側の変数 line に入れる（サブシェルを避けるため）。
# 「空白 + # + 空白」以降はコメント。# で始まる行をどう扱うかは呼び出し側で決める
_peacock_strip() {
  line="$1"
  # zsh の EXTENDED_GLOB では素の # がパターン演算子になるためエスケープしている
  line="${line%%[[:space:]]\#[[:space:]]*}"
  line="${line%[[:space:]]\#}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
}

# 設定の1行を解釈し、呼び出し側の変数 key / value に入れる。対応キーの正しい値でなければ失敗する。
#   - `key=value` 形式。= の前後の空白は無視する
#   - 色だけを書いた行（#rrggbb）は background として扱う
#   - # で始まる行（色だけの行を除く）と、「空白 + # + 空白」以降はコメント
_peacock_parse_line() {
  local line hex
  _peacock_strip "$1"
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
    # 配色ではなくコマンド連動のセクションの当たり判定。.peacock の読み込みと描画には渡さない
    match-options)
      _peacock_parse_conditions "$value" || return 1
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
    [[ "$key" == match-options ]] && continue
    [[ "$seen" == *" $key "* ]] && continue
    seen="$seen$key "
    printf '%s=%s\n' "$key" "$value"
  done < "$file"
}

# 最寄りの .peacock、またはコマンドの実行中ならその設定から、実際に適用する設定を出力する
_peacock_resolve() {
  local file config=""
  if [[ -n "$_PEACOCK_CMD" ]]; then
    _peacock_config_file "$_PEACOCK_CMD"
    if [[ -f "$file" ]]; then
      config="$(_peacock_read_section "$file" "$_PEACOCK_SECTION")"
    fi
    if [[ -n "$config" ]]; then
      # 何につないでいるかが分かる目印がなければ、当てはまった語（match-options ならセクション名）をバッジに出す
      if [[ "${PEACOCK_COMMAND_BADGE:-1}" != 0 && $'\n'"$config" != *$'\n'badge=* ]]; then
        config="$config"$'\n'"badge=$_PEACOCK_TARGET"
      fi
      _peacock_finalize "$config"
      return 0
    fi
    config=""
  fi
  if file="$(_peacock_find)"; then
    config="$(_peacock_read "$file")"
  fi
  _peacock_finalize "$config"
}

# 設定（_peacock_read などの出力）に、ファイル外の規則を足して適用する設定にする。
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

# プロンプトを出す直前に呼ぶ。コマンドから戻っていれば、ここでその配色が解けて元に戻る
_peacock_precmd() {
  _PEACOCK_CMD=""
  _PEACOCK_SECTION=""
  _PEACOCK_TARGET=""
  _peacock_apply
}

# ---- コマンド連動 ----
# 設定ファイルを持つコマンドを実行している間だけ、その配色にする。
# コマンド名と当てはまったセクションを _PEACOCK_CMD / _PEACOCK_SECTION / _PEACOCK_TARGET に入れると、
# 解決がディレクトリの .peacock ではなく <コマンド名>.ini の当てはまるセクションを使う。
# 元に戻すのはこれらを空にして塗り直すだけでよく、
# コマンド側にしかなかったキーは差分描画がプロファイルの色へ戻す。
#
# 対象にするコマンドの一覧はどこにも持たない。<コマンド名>.ini があることがフックの宣言になる。

# 設定ファイルを置くディレクトリを呼び出し側の変数 dir に入れる
_peacock_config_dir() {
  if [[ -n "${PEACOCK_CONFIG_DIR:-}" ]]; then
    dir="$PEACOCK_CONFIG_DIR"
  else
    dir="${XDG_CONFIG_HOME:-$HOME/.config}/iterm-peacock"
  fi
}

# コマンド名に対応する設定ファイルのパスを呼び出し側の変数 file に入れる
_peacock_config_file() {
  local dir
  _peacock_config_dir
  file="$dir/$1.ini"
}

# 空白区切りのパターンのどれかが value に当てはまるかを調べる
_peacock_matches() {
  # zsh は case の右辺に置いた変数をパターンとして扱わないため、この関数の中だけ GLOB_SUBST を有効にする
  [[ -z "${ZSH_VERSION:-}" ]] || setopt localoptions globsubst
  local value="$1" patterns="$2" pattern
  while [[ -n "$patterns" ]]; do
    pattern="${patterns%%[[:space:]]*}"
    if [[ "$pattern" == "$patterns" ]]; then
      patterns=""
    else
      patterns="${patterns#*[[:space:]]}"
      patterns="${patterns#"${patterns%%[![:space:]]*}"}"
    fi
    [[ -n "$pattern" ]] || continue
    case "$value" in
      $pattern) return 0 ;;
    esac
  done
  return 1
}

# 空白区切りの文字列 rest から先頭の1語を呼び出し側の変数 token に取り出し、rest を残りにする。語がなければ失敗する
_peacock_next_token() {
  rest="${rest#"${rest%%[![:space:]]*}"}"
  [[ -n "$rest" ]] || return 1
  token="${rest%%[[:space:]]*}"
  rest="${rest#"$token"}"
}

# match-options の値を検査し、条件を空白1つ区切りに揃えて呼び出し側の変数 value に入れる。
# 条件は2種類で、- で始まるものは <オプション名>=<値のパターン>（名前は | で別名を並べ、どれも - で始まる）、
# それ以外は語のパターン。条件が1つもない、名前か値のパターンが空なら失敗する
_peacock_parse_conditions() {
  local rest="$1" token names name out=""
  while _peacock_next_token; do
    case "$token" in
      -*)
        [[ "$token" == *=* && -n "${token#*=}" ]] || return 1
        names="${token%%=*}|"
        while [[ -n "$names" ]]; do
          name="${names%%|*}"
          names="${names#*|}"
          case "$name" in
            ""|-|--|[!-]*) return 1 ;;
          esac
        done
        ;;
    esac
    out="${out:+$out }$token"
  done
  [[ -n "$out" ]] || return 1
  value="$out"
}

# 語のどれかが空白区切りのパターンに当てはまるかを調べ、当てはまった最初の語を呼び出し側の変数 word に入れる。
# コマンドごとのオプションの文法は持たないため、- で始まる語（オプション名）だけを除いて照合する
_peacock_match_word() {
  local patterns="$1"
  shift
  for word in "$@"; do
    case "$word" in
      -*|"") continue ;;
    esac
    _peacock_matches "$word" "$patterns" && return 0
  done
  return 1
}

# コマンド行の語から、names（| 区切りのオプション名）に渡された値を呼び出し側の変数 value に入れる。
# 値を取るかどうかはコマンドの文法ではなく、設定にその名前が書かれていることで決まる。
#   --port=V / --port V    -- で始まる名前は = の後ろか次の語
#   -P V / -PV             - で始まる名前は次の語か、名前に続く残り
# 同じオプションが何度もあれば最後の値を使い、-- より後ろはオプションとして読まない。値がなければ失敗する
_peacock_option_value() {
  local names="$1|" arg rest name found=1
  shift
  while [[ $# -gt 0 ]]; do
    arg="$1"
    shift
    [[ "$arg" != -- ]] || break
    rest="$names"
    while [[ -n "$rest" ]]; do
      name="${rest%%|*}"
      rest="${rest#*|}"
      if [[ "$arg" == "$name" ]]; then
        if [[ $# -gt 0 ]]; then
          value="$1"
          found=0
          shift
        fi
        break
      fi
      case "$name" in
        --*)
          [[ "$arg" == "$name="* ]] || continue
          value="${arg#"$name="}"
          ;;
        *)
          [[ "$arg" == "$name"?* ]] || continue
          value="${arg#"$name"}"
          ;;
      esac
      found=0
      break
    done
  done
  return $found
}

# match-options の条件がすべてコマンド行の語に当てはまるかを調べ、条件の数を呼び出し側の変数 count に入れる
_peacock_match_conditions() {
  local rest="$1" token value word
  shift
  count=0
  while _peacock_next_token; do
    case "$token" in
      -*)
        _peacock_option_value "${token%%=*}" "$@" || return 1
        _peacock_matches "$value" "${token#*=}" || return 1
        ;;
      *)
        _peacock_match_word "$token" "$@" || return 1
        ;;
    esac
    count=$((count + 1))
  done
}

# 設定ファイルのセクションからコマンド行の語に当てはまるものを選び、その番号（見出しを上から数えて1始まり）を
# 呼び出し側の変数 section に、バッジの既定値を target に入れる。当てはまるものがなければ失敗する。
#   - match-options のないセクションは、見出しのパターンのどれかに語が当たれば当てはまる。
#     条件の数は1で、バッジの既定値は当てはまった語
#   - match-options のあるセクションは、見出しをパターンではなく名前として扱い、条件がすべて当たれば当てはまる。
#     条件の数は並べた数で、バッジの既定値は見出しの名前。最初の match-options の行が読めなければ当てはまらない
# 当てはまったうち条件の数が最も多いものを選び、同じ数なら後に書いたものを選ぶ（具体的に書いた方が勝つ）
_peacock_find_section() {
  local file="$1" raw line key value index=0 header="" options="" kind="" best=0
  shift
  section=""
  target=""
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    _peacock_strip "$raw"
    case "$line" in
      \[*\])
        _peacock_rank_section "$@"
        index=$((index + 1))
        header="${line#\[}"
        header="${header%\]}"
        options=""
        kind=""
        ;;
      match-options*)
        [[ $index -gt 0 && -z "$kind" ]] || continue
        key="${line%%=*}"
        [[ "${key%"${key##*[![:space:]]}"}" == match-options ]] || continue
        if _peacock_parse_line "$line"; then
          options="$value"
          kind=ok
        else
          kind=broken
        fi
        ;;
    esac
  done < "$file"
  _peacock_rank_section "$@"
  [[ -n "$section" ]]
}

# _peacock_find_section が読み終えた1つのセクションを評価し、それまでの候補より優先するなら入れ替える
_peacock_rank_section() {
  local count word
  [[ $index -gt 0 ]] || return 0
  case "$kind" in
    broken) return 0 ;;
    ok)
      _peacock_match_conditions "$options" "$@" || return 0
      word="$header"
      ;;
    *)
      _peacock_match_word "$header" "$@" || return 0
      count=1
      ;;
  esac
  [[ $count -ge $best ]] || return 0
  best=$count
  section=$index
  target="$word"
}

# 設定ファイルの index 番目（見出しを上から数えて1始まり）のセクションの設定を key=value の改行区切りで出力する。
# 見出しより前の行とほかのセクションの行は読み飛ばす。同じキーはセクション内の最初の行を使い、
# match-options は配色の設定ではないため出力しない
_peacock_read_section() {
  local file="$1" index="$2" raw line key value seen=" " current=0
  [[ -n "$index" ]] || return 0
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    _peacock_strip "$raw"
    [[ -n "$line" ]] || continue
    case "$line" in
      \[*\])
        [[ $current -ne $index ]] || return 0
        current=$((current + 1))
        continue
        ;;
    esac
    [[ $current -eq $index ]] || continue
    _peacock_parse_line "$line" || continue
    [[ "$key" != match-options ]] || continue
    [[ "$seen" == *" $key "* ]] && continue
    seen="$seen$key "
    printf '%s=%s\n' "$key" "$value"
  done < "$file"
}

# コマンド行の語から、実行されるコマンド名を呼び出し側の変数 name に、
# そのコマンド名までの語数を skip に入れる（環境変数の前置きと command を読み飛ばす）
_peacock_command_name() {
  skip=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      [A-Za-z_]*=*|command|\\command) shift; skip=$((skip + 1)) ;;
      *) break ;;
    esac
  done
  [[ $# -gt 0 ]] || return 1
  name="${1##*/}"
  name="${name#\\}"
  skip=$((skip + 1))
}

# ssh の引数から接続先を取り出し、呼び出し側の変数 host に入れる。
# ssh だけはオプションの文法が分かっているため、語の総当たりではなく接続先そのものを見る。
# ログインと -N のトンネル以外（リモートコマンド付き、端末を占有しないオプション、接続先なし）では失敗する
_peacock_ssh_target() {
  local arg flags count i char takes
  host=""
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --) shift; break ;;
      -?*)
        flags="${arg#-}"
        count=${#flags}
        i=0
        takes=0
        while [[ $i -lt $count ]]; do
          char="${flags:$i:1}"
          i=$((i + 1))
          case "$char" in
            # 端末を占有しない使い方なので色は変えない。
            # -N（トンネル専用）はフォアグラウンドで端末を占有し続けるため対象に含める
            f|G|O|W) return 1 ;;
            # 値を取るオプション。同じ語に値が続いていればそれが値、なければ次の語が値
            [BbcDEeFIiJLlmoPpQRSw])
              if [[ $i -lt $count ]]; then
                i=$count
              else
                takes=1
              fi
              ;;
          esac
        done
        shift
        if [[ $takes -eq 1 ]]; then
          [[ $# -gt 0 ]] || return 1
          shift
        fi
        ;;
      *) break ;;
    esac
  done
  # 接続先だけが残っていなければ、リモートコマンド付きか接続先なし
  [[ $# -eq 1 ]] || return 1
  host="$1"
  case "$host" in
    ssh://*)
      host="${host#ssh://}"
      host="${host%%/*}"
      host="${host#*@}"
      host="${host%%:*}"
      ;;
    *) host="${host#*@}" ;;
  esac
  [[ -n "$host" ]] || return 1
}

# コマンド行の語から設定に当てはまるセクションを探し、当てはまればその配色に切り替える。
# 元に戻すのは _peacock_precmd（zsh）とラッパー（bash）が担う
_peacock_enter() {
  local name skip file section target host
  _peacock_command_name "$@" || return 1
  _peacock_config_file "$name"
  [[ -f "$file" ]] || return 1
  shift $skip
  if [[ "$name" == ssh ]]; then
    _peacock_ssh_target "$@" || return 1
    set -- "$host"
  fi
  _peacock_find_section "$file" "$@" || return 1
  _PEACOCK_CMD="$name"
  _PEACOCK_SECTION="$section"
  _PEACOCK_TARGET="$target"
  _peacock_apply
}

# コマンドをラップして、実行している間だけ設定に合わせた配色にする（bash 用の入口）。
# zsh ではプラグインの preexec が同じ役目を担うため、コマンドをラップしない
_peacock_wrap() {
  local name="$1" code
  shift
  _peacock_enter "$name" "$@" || true
  command "$name" "$@"
  code=$?
  _PEACOCK_CMD=""
  _PEACOCK_SECTION=""
  _PEACOCK_TARGET=""
  _peacock_apply
  return $code
}

# 設定ファイルのあるコマンドの分だけラッパー関数を定義する（bash 用）。
# zsh と違い読み込んだ時点の顔ぶれで固定されるため、.ini を足したら読み込み直す
_peacock_wrap_commands() {
  local dir file name
  _peacock_config_dir
  [[ -d "$dir" ]] || return 0
  for file in "$dir"/*.ini; do
    [[ -f "$file" ]] || continue
    name="${file##*/}"
    name="${name%.ini}"
    # 関数名にできない名前のファイルは、eval に渡さず読み飛ばす
    case "$name" in
      ""|*[!A-Za-z0-9_-]*) continue ;;
    esac
    eval "$name() { _peacock_wrap $name \"\$@\"; }"
  done
}
