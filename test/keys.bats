#!/usr/bin/env bats
# キーごとの設定・リセットのエスケープシーケンスのテスト。
# 各ケースはシェル名を引数に取る関数として書き、末尾で bash / zsh の両方に登録する。

load test_helper

# .peacock を置いたディレクトリで塗り、外に出て戻す。出力は「塗った分 SEP 戻した分」になる
apply_and_leave() {
  local shell="$1"
  mkdir -p colored plain
  cat > colored/.peacock
  run_hook "$shell" "cd colored; _peacock_apply; printf SEP; cd ../plain; _peacock_apply"
  [ "$status" -eq 0 ]
  set_part="${output%%SEP*}"
  reset_part="${output#*SEP}"
}

case_dynamic_colors() {
  apply_and_leave "$1" <<'EOF'
foreground=#eeeeee
cursor=#ffcc00
selection=#553333
selection-text=#ffffff
EOF
  [ "$set_part" = "${ESC}]10;rgb:ee/ee/ee${BEL}${ESC}]12;rgb:ff/cc/00${BEL}${ESC}]17;rgb:55/33/33${BEL}${ESC}]19;rgb:ff/ff/ff${BEL}" ]
  [ "$reset_part" = "${ESC}]110${BEL}${ESC}]112${BEL}${ESC}]117${BEL}${ESC}]119${BEL}" ]
}

case_tab_can_differ_from_background() {
  apply_and_leave "$1" <<'EOF'
background=#000000
tab=#ff5f5f
EOF
  [ "$set_part" = "$(bg_seq 000000)${ESC}]6;1;bg;red;brightness;255${BEL}${ESC}]6;1;bg;green;brightness;95${BEL}${ESC}]6;1;bg;blue;brightness;95${BEL}" ]
  [ "$reset_part" = "$RESET" ]
}

case_tab_without_background() {
  apply_and_leave "$1" <<'EOF'
tab=#ff5f5f
EOF
  [[ "$set_part" != *"]11;"* ]]
  [ "$reset_part" = "${ESC}]6;1;bg;*;default${BEL}" ]
}

case_ansi_colors() {
  apply_and_leave "$1" <<'EOF'
black=#101010
red=#ff0000
bright-white=#fafafa
EOF
  [ "$set_part" = "${ESC}]4;0;rgb:10/10/10${BEL}${ESC}]4;1;rgb:ff/00/00${BEL}${ESC}]4;15;rgb:fa/fa/fa${BEL}" ]
  [ "$reset_part" = "${ESC}]104;0${BEL}${ESC}]104;1${BEL}${ESC}]104;15${BEL}" ]
}

case_all_ansi_names() {
  apply_and_leave "$1" <<'EOF'
black=#000000
red=#000000
green=#000000
yellow=#000000
blue=#000000
magenta=#000000
cyan=#000000
white=#000000
bright-black=#000000
bright-red=#000000
bright-green=#000000
bright-yellow=#000000
bright-blue=#000000
bright-magenta=#000000
bright-cyan=#000000
bright-white=#000000
EOF
  local i expected=""
  for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    expected="$expected${ESC}]4;$i;rgb:00/00/00${BEL}"
  done
  [ "$set_part" = "$expected" ]
}

case_badge() {
  apply_and_leave "$1" <<'EOF'
badge = My Project  # 右上に出す
EOF
  [ "$set_part" = "${ESC}]1337;SetBadgeFormat=$(printf '%s' 'My Project' | base64)${BEL}" ]
  [ "$reset_part" = "${ESC}]1337;SetBadgeFormat=${BEL}" ]
}

case_badge_keeps_hash_in_text() {
  apply_and_leave "$1" <<'EOF'
badge=C# app #1
EOF
  [ "$set_part" = "${ESC}]1337;SetBadgeFormat=$(printf '%s' 'C# app #1' | base64)${BEL}" ]
}

case_cursor_guide() {
  apply_and_leave "$1" <<'EOF'
cursor-guide=on
EOF
  [ "$set_part" = "${ESC}]1337;HighlightCursorLine=yes${BEL}" ]
  [ "$reset_part" = "${ESC}]1337;HighlightCursorLine=no${BEL}" ]
}

case_invalid_values_are_ignored() {
  apply_and_leave "$1" <<'EOF'
foreground=white
cursor-guide=maybe
badge=
red=#12345
EOF
  [ -z "$set_part" ]
  [ -z "$reset_part" ]
}

for shell in bash zsh; do
  bats_test_function --description "[$shell] foreground / cursor / selection / selection-text を設定・リセットする" -- case_dynamic_colors "$shell"
  bats_test_function --description "[$shell] tab を background と別の色にできる" -- case_tab_can_differ_from_background "$shell"
  bats_test_function --description "[$shell] background なしで tab だけ設定できる" -- case_tab_without_background "$shell"
  bats_test_function --description "[$shell] ANSI 色をパレット番号で設定・リセットする" -- case_ansi_colors "$shell"
  bats_test_function --description "[$shell] ANSI 16色の名前が 0〜15 番に対応する" -- case_all_ansi_names "$shell"
  bats_test_function --description "[$shell] badge を base64 で設定し、空に戻す" -- case_badge "$shell"
  bats_test_function --description "[$shell] badge の文字に含まれる # を残す" -- case_badge_keeps_hash_in_text "$shell"
  bats_test_function --description "[$shell] cursor-guide を yes / no で切り替える" -- case_cursor_guide "$shell"
  bats_test_function --description "[$shell] 不正な値のキーは無視する" -- case_invalid_values_are_ignored "$shell"
done
