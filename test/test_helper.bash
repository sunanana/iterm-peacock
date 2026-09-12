# テスト共通の定数とセットアップ。各 .bats から `load test_helper` で読み込む。

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
HOOK="$REPO/iterm-peacock.sh"
PLUGIN="$REPO/iterm-peacock.plugin.zsh"
BIN="$REPO/bin/iterm-peacock"

ESC=$'\e'
BEL=$'\a'
RESET="${ESC}]111${BEL}${ESC}]6;1;bg;*;default${BEL}"

# 背景色を変える OSC 11 の期待値
bg_seq() {
  local hex="$1"
  printf '%s]11;rgb:%s/%s/%s%s' "$ESC" "${hex:0:2}" "${hex:2:2}" "${hex:4:2}" "$BEL"
}

# タブ色を変える iTerm2 独自シーケンス（赤・緑・青の3つ組）の期待値
tab_seq() {
  local hex="$1" color
  for color in red green blue; do
    printf '%s]6;1;bg;%s;brightness;%d%s' "$ESC" "$color" "$((16#${hex:0:2}))" "$BEL"
    hex="${hex:2}"
  done
}

# バッジを設定する OSC 1337 の期待値
badge_seq() {
  printf '%s]1337;SetBadgeFormat=%s%s' "$ESC" "$(printf '%s' "$1" | base64 | tr -d '\n')" "$BEL"
}

setup() {
  cd "$BATS_TEST_TMPDIR"
}

# 疑似端末（script コマンド）の中でコマンドを実行し、keys（printf の書式）をキー入力として送る。
# keys は | で区切ると、区切りごとに少し間を空けて送る（人がキーを押す間隔に近づける。
# ピッカーは描き終えるまでに届いたキーを捨てるため、まとめて送ると後ろのキーが捨てられる）。
# 起動直後の端末モードの切り替えと DSR の応答確認が終わるまで待ってから送り（PTY_START_DELAY 秒）、
# 入力が閉じると Ctrl+D が送られるため、コマンドが終わるまで入力を開いたままにする
run_in_pty() {
  local keys="$1" feed="sleep ${PTY_START_DELAY:-1.0}" part
  shift
  while [[ -n "$keys" ]]; do
    part="${keys%%|*}"
    feed="$feed; printf '$part'; sleep 0.2"
    [[ "$keys" == *"|"* ]] && keys="${keys#*|}" || keys=""
  done
  run bash -c "($feed; sleep 1.2) | script -q /dev/null $(printf '%q ' "$@")"
}

# 指定したシェルでフックを source してからコマンド列を実行する。
# ユーザーの rc ファイルの影響を受けないよう、起動ファイルは読ませない。
run_hook() {
  local shell="$1"; shift
  case "$shell" in
    bash) run bash --norc --noprofile -c "source '$HOOK'; $*" ;;
    zsh) run zsh -f -c "source '$HOOK'; $*" ;;
    *) echo "unknown shell: $shell" >&2; return 1 ;;
  esac
}
