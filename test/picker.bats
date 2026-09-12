#!/usr/bin/env bats
# 配色ピッカー（引数なしの iterm-peacock）のテスト。
# キー入力が必要なため、疑似端末の中で実行する（run_in_pty）。
# 日本語のテスト名を使うため、@test ではなく関数を bats_test_function で登録している。

load test_helper

BATS_TEST_TIMEOUT=20

# キーの区切り（|）込みの矢印キー。run_in_pty は | ごとに間を空けて送る
UP='\033[A|'
DOWN='\033[B|'
# 端末が DSR（ESC [ 5 n）に返す応答
REPLY='\033[0n'

# k 番目（1ページ10件の通し番号）の候補を
# 「背景 文字 タブ カーソル 選択範囲 選択範囲の文字 赤 緑 黄 青」で出力する。
# 色相の種は既定でカレントディレクトリ名。セクションに向けたときは SEED に見出しを入れる
candidate() {
  SEED="${SEED:-${PWD##*/}}" bash -c "source '$BIN'; _suggest_page \"\$(_hue_of \"\$SEED\")\" $(($1 / 10)) | sed -n $(($1 % 10 + 1))p"
}

# 候補 k の各色を .peacock の行にしたもの
candidate_lines() {
  local bg fg tab cursor sel selt red green yellow blue
  read -r bg fg tab cursor sel selt red green yellow blue <<< "$(candidate "$1")"
  printf 'background=#%s\nforeground=#%s\ntab=#%s\ncursor=#%s\nselection=#%s\nselection-text=#%s\nred=#%s\ngreen=#%s\nyellow=#%s\nblue=#%s' \
    "$bg" "$fg" "$tab" "$cursor" "$sel" "$selt" "$red" "$green" "$yellow" "$blue"
}

# 候補 k を（バッジ・カーソルガイドなしで）保存したときの .peacock の内容
candidate_file() {
  candidate_lines "$1"
}

case_enter_saves_first_candidate() {
  run_in_pty '\r' "$BIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved -> $BATS_TEST_TMPDIR/.peacock"* ]]
  [ "$(cat .peacock)" = "$(candidate_file 0)" ]
}

case_down_selects_next_row() {
  run_in_pty "$DOWN$DOWN"'\r' "$BIN"
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = "$(candidate_file 2)" ]
}

case_up_wraps_to_last_row() {
  # 1行目の候補 → Cursor guide → Badge → 最後の候補
  run_in_pty "$UP$UP$UP"'\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 9)" ]
}

case_down_wraps_to_first_row() {
  # 最後の候補 → Badge → Cursor guide → 1行目の候補
  run_in_pty "$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN$DOWN"'\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 0)" ]
}

case_tab_shows_next_list() {
  run_in_pty '\t|'"$DOWN"'\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 11)" ]
}

case_ss3_arrow_keys() {
  run_in_pty '\033OB|\033OB|\033OA|\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 1)" ]
}

case_other_keys_are_ignored() {
  run_in_pty '\033[C|\033[D|x|q|b|g|\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 0)" ]
}

case_space_on_color_row_does_nothing() {
  run_in_pty ' |\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 0)" ]
}

case_badge_row_adds_dir_name() {
  mkdir -p my-app
  cd my-app
  run_in_pty "$UP$UP"' |\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_lines 0)"$'\nbadge=my-app' ]
  [[ "$output" == *"SetBadgeFormat=$(printf my-app | base64)"* ]]
}

case_badge_row_toggles_off() {
  run_in_pty "$UP$UP"' | |\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 0)" ]
}

case_existing_badge_can_be_turned_off() {
  printf 'badge=PROD\n' > .peacock
  run_in_pty "$UP$UP"' |\r' "$BIN"
  [[ "$(cat .peacock)" != *badge* ]]
}

case_cursor_guide_row_adds_guide() {
  run_in_pty "$UP"' |\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_lines 0)"$'\ncursor-guide=yes' ]
  [[ "$output" == *"HighlightCursorLine=yes"* ]]
}

case_tab_keeps_focus_on_settings() {
  # Cursor guide の行にいるまま Tab で次の一覧に切り替えても、Space は Cursor guide に効く
  run_in_pty "$UP"'\t| |\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_lines 10)"$'\ncursor-guide=yes' ]
}

case_toggle_state_is_shown() {
  run_in_pty "$UP"' |\033' "$BIN"
  [[ "$output" == *"$(printf '  %-29s%-5s' Badge off)"* ]]
  [[ "$output" == *"$(printf '❯ %-29s%-5s' 'Cursor guide' on)"* ]]
}

case_preview_follows_selection() {
  local bg fg tab
  read -r bg fg tab <<< "$(candidate 1)"
  run_in_pty "$DOWN"'\r' "$BIN"
  [[ "$output" == *"$(bg_seq "$bg")"* ]]
  [[ "$output" == *"${ESC}]10;rgb:${fg:0:2}/${fg:2:2}/${fg:4:2}${BEL}"* ]]
}

case_list_shows_labels_and_rows() {
  run_in_pty '\033' "$BIN"
  [[ "$output" == *"= = = ="*$'\e[7m Options \e[0m'*"Badge"*"Cursor guide"*"Space: toggle"*$'\e[7m Colors \e[0m'*"BG"*"Text"*"Tab"*"Cursor"*"Select"*"Sample"*"Tab: more colors"*"Enter: save  Esc: cancel"*"= = = ="* ]]
  # 10行 × 6つの色見本（24bit の背景色）
  [ "$(grep -o $'\e\[48;2;' <<< "$output" | wc -l | tr -d ' ')" -ge 60 ]
  [[ "$output" == *'$ sample '*'err '*'ok '*'warn '*'info '* ]]
  [[ "$output" != *'$ ls'* ]]
}

# 描き終えたらカーソルを選んでいる行に置く。
# カーソルガイドのハイライトは、隠していてもカーソルのある行に出るため
case_cursor_is_placed_on_selected_row() {
  # 描き終えると最下行（23行目）にいるので、候補の1行目（10行目）へは13行、2行目へは12行上がる
  run_in_pty "$DOWN$DOWN"'\033' "$BIN"
  [[ "$output" == *$'\e[13A'* ]]
  [[ "$output" == *$'\e[12A'* ]]
  [[ "$output" == *$'\e[11A'* ]]
}

case_starts_with_blank_line_and_frame() {
  run_in_pty '\033' "$BIN"
  # 画面を隠す・配色の試し表示のエスケープの後、最初に空行、次に上の線を描く
  local first="${output#*$'\e[?25l'}"
  first="$(LC_ALL=C sed -e $'s/\e\\][^\a]*\a//g' -e $'s/\e\\[K//g' <<< "$first" | tr -d '\r' | head -2)"
  [ "$first" = $'\n= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =' ]
}

case_cursor_is_placed_on_setting_row() {
  # Cursor guide（5行目）へは18行上がる
  run_in_pty "$UP"'\033' "$BIN"
  [[ "$output" == *$'\e[18A'* ]]
}

case_no_color_codes_in_list() {
  local bg fg tab
  read -r bg fg tab <<< "$(candidate 0)"
  run_in_pty '\033' "$BIN"
  [[ "$output" != *"#$bg"* ]]
  [[ "$output" != *"$fg"* ]]
  [[ "$output" != *"background="* ]]
}

case_esc_cancels_and_restores() {
  run_in_pty "$DOWN"'\033' "$BIN"
  [ "$status" -eq 0 ]
  [ ! -e .peacock ]
  [[ "$output" == *"canceled"*"${ESC}]111${BEL}"* ]]
  [[ "$output" == *"canceled"*"${ESC}]110${BEL}"* ]]
  [[ "$output" == *"canceled"*"${ESC}]6;1;bg;*;default${BEL}"* ]]
}

case_esc_restores_parent_settings() {
  printf 'background=#330000\nbadge=PARENT\n' > .peacock
  mkdir -p sub
  cd sub
  run_in_pty '\033' "$BIN"
  [ ! -e .peacock ]
  local after="${output##*canceled}"
  [[ "$after" == *"$(bg_seq 330000)"* ]]
  [[ "$after" == *"${ESC}]110${BEL}"* ]]
  [[ "$after" == *"SetBadgeFormat=$(printf PARENT | base64)"* ]]
}

case_ctrl_d_cancels() {
  run_in_pty '\004' "$BIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"canceled"* ]]
  [ ! -e .peacock ]
}

case_ctrl_c_cancels_and_restores() {
  run_in_pty "$DOWN"'\003' "$BIN"
  [ ! -e .peacock ]
  [[ "$output" == *"canceled"*"${ESC}]111${BEL}"*"${ESC}[?25h"* ]]
}

case_keeps_other_lines() {
  printf '# note\nbadge=PROD\nbackground=#000000\nmagenta=#ff00ff\n' > .peacock
  run_in_pty '\r' "$BIN"
  local lines
  lines="$(candidate_lines 0)"
  # background はその位置で置き換え、残りの候補の色は末尾に足す。バッジは既存の文字のまま残る
  [ "$(cat .peacock)" = $'# note\nbadge=PROD\n'"${lines%%$'\n'*}"$'\nmagenta=#ff00ff\n'"${lines#*$'\n'}" ]
}

case_section_enter_saves_into_ini() {
  local SEED='[prod-db-*]'
  mkdir -p config
  export PEACOCK_CONFIG_DIR="$PWD/config"
  run_in_pty '\r' "$BIN" cmd mysql set 'prod-db-*'
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved -> $PWD/config/mysql.ini [prod-db-*]"* ]]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\n'"$(candidate_lines 0)" ]
}

case_section_keeps_the_rest_of_the_file() {
  local SEED='[prod-db-*]'
  mkdir -p config
  export PEACOCK_CONFIG_DIR="$PWD/config"
  printf '# hosts\n[prod-db-*]\nbadge=PRODUCTION\n\n[staging-db-*]\nbackground=#000030\n' > config/mysql.ini
  run_in_pty '\r' "$BIN" cmd mysql set 'prod-db-*'
  [ "$status" -eq 0 ]
  # 見出しの中身だけを差し替え、前のコメント・後ろのセクション・その間の空行はそのまま残す
  [ "$(cat config/mysql.ini)" = $'# hosts\n[prod-db-*]\nbadge=PRODUCTION\n'"$(candidate_lines 0)"$'\n\n[staging-db-*]\nbackground=#000030' ]
}

case_section_badge_defaults_to_pattern() {
  local SEED='[prod-db-*]'
  mkdir -p config
  export PEACOCK_CONFIG_DIR="$PWD/config"
  run_in_pty "$UP$UP"' |\r' "$BIN" cmd mysql set 'prod-db-*'
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\n'"$(candidate_lines 0)"$'\nbadge=prod-db-*' ]
}

case_section_cancel_writes_nothing() {
  mkdir -p config
  export PEACOCK_CONFIG_DIR="$PWD/config"
  run_in_pty '\033' "$BIN" cmd mysql set 'prod-db-*'
  [ "$status" -eq 0 ]
  [[ "$output" == *canceled* ]]
  [ ! -e config/mysql.ini ]
}

case_section_requires_a_pattern() {
  mkdir -p config
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set
  [ "$status" -eq 1 ]
  [[ "$output" == *'cmd mysql set <pattern>'* ]]
}

case_requires_terminal() {
  run "$BIN" < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs a terminal"* ]]
}

case_same_dir_name_same_start() {
  mkdir -p a/project b/project
  local first second
  first="$(cd a/project && candidate 0)"
  second="$(cd b/project && candidate 0)"
  [ "$first" = "$second" ]
}

case_list_has_no_duplicates() {
  local page
  for page in 0 1 2; do
    [ "$(bash -c "source '$BIN'; _suggest_page 42 $page" | sort -u | wc -l | tr -d ' ')" = 10 ]
  done
}

# 背景は暗く、コントラスト比（WCAG）が 文字色は 7 以上、選択範囲の文字と ANSI 色は 4.5 以上であること
case_candidates_are_readable() {
  local h page
  for h in 0 30 60 90 120 150 180 210 240 270 300 330; do
    for page in 0 1; do
      bash -c "source '$BIN'; _suggest_page $h $page" | awk '
        function hexv(s, i) { return index("0123456789abcdef", substr(s, i, 1)) - 1 }
        function c(s, i,   v) { v = (hexv(s, i) * 16 + hexv(s, i + 1)) / 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
        function lum(s) { return 0.2126 * c(s, 1) + 0.7152 * c(s, 3) + 0.0722 * c(s, 5) }
        function ratio(a, b) { return (lum(a) + 0.05) / (lum(b) + 0.05) }
        function check(name, value, min) { if (value < min) { print name " " $0 " ratio=" value; bad = 1 } }
        {
          if (lum($1) > 0.04) { print "bright bg " $0; bad = 1 }
          check("text", ratio($2, $1), 7)
          check("selection-text", ratio($6, $5), 4.5)
          check("red", ratio($7, $1), 4.5)
          check("green", ratio($8, $1), 4.5)
          check("yellow", ratio($9, $1), 4.5)
          check("blue", ratio($10, $1), 4.5)
        }
        END { exit bad }'
    done
  done
}

# ---- 端末との同期（DSR） ----
# 疑似端末は DSR に応答しないため、テストでは応答（REPLY）をキー入力と同じ経路で送って端末を模擬する。
# 起動時の応答確認に間に合うよう、これらのテストは早めにキーを送り始める

case_sync_drops_keys_while_terminal_is_busy() {
  # ↓ で描き直した後、端末の応答が返るまでに届いた ↓×4 は捨てる
  PTY_START_DELAY=0.3 run_in_pty "$REPLY|$DOWN"'\033[B\033[B\033[B\033[B|'"$REPLY"'|\r' "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 1)" ]
}

case_sync_esc_while_terminal_is_busy() {
  # 端末の応答を待っている間に届いた Esc は、溜まった ↓ より優先して即座にやめる
  PTY_START_DELAY=0.3 run_in_pty "$REPLY|$DOWN"'\033[B\033[B\033' "$BIN"
  [ ! -e .peacock ]
  [[ "$output" == *"canceled"* ]]
}

case_sync_enter_while_terminal_is_busy() {
  # 端末の応答を待っている間に届いた Enter は、応答が返った後に保存する
  PTY_START_DELAY=0.3 run_in_pty "$REPLY|$DOWN"'\033[B\r|'"$REPLY" "$BIN"
  [ "$(cat .peacock)" = "$(candidate_file 1)" ]
}

case_sync_sends_dsr_after_each_draw() {
  PTY_START_DELAY=0.3 run_in_pty "$REPLY|$DOWN$REPLY|"'\r' "$BIN"
  # 起動時の確認と ↓ の後の2回
  [ "$(grep -o $'\e\[5n' <<< "$output" | wc -l | tr -d ' ')" = 2 ]
}

case_no_sync_without_reply() {
  # DSR に応答しない端末では、起動時の確認の1回だけで以降は送らない
  run_in_pty "$DOWN$DOWN"'\r' "$BIN"
  [ "$(grep -o $'\e\[5n' <<< "$output" | wc -l | tr -d ' ')" = 1 ]
  [ "$(cat .peacock)" = "$(candidate_file 2)" ]
}

bats_test_function --description "Enter で選んでいる候補（最初は1行目）を保存する" -- case_enter_saves_first_candidate
bats_test_function --description "↓ で次の行を選ぶ" -- case_down_selects_next_row
bats_test_function --description "1行目の候補から ↑ で設定欄を通り、最後の候補に回り込む" -- case_up_wraps_to_last_row
bats_test_function --description "最後の候補から ↓ で設定欄を通り、1行目の候補に回り込む" -- case_down_wraps_to_first_row
bats_test_function --description "Tab で別の候補の一覧に切り替わる" -- case_tab_shows_next_list
bats_test_function --description "ESC O 形式の矢印キーも受け付ける" -- case_ss3_arrow_keys
bats_test_function --description "左右キーや文字キーは無視する" -- case_other_keys_are_ignored
bats_test_function --description "色の候補の行で Space を押しても何も変わらない" -- case_space_on_color_row_does_nothing
bats_test_function --description "Badge の行で Space を押すとディレクトリ名のバッジを付ける" -- case_badge_row_adds_dir_name
bats_test_function --description "Badge の行で Space をもう一度押すとバッジを外す" -- case_badge_row_toggles_off
bats_test_function --description "既存のバッジは Badge の行で外せる" -- case_existing_badge_can_be_turned_off
bats_test_function --description "Cursor guide の行で Space を押すとカーソルガイドを付ける" -- case_cursor_guide_row_adds_guide
bats_test_function --description "設定欄にいるまま Tab を押しても選んでいる設定の行は変わらない" -- case_tab_keeps_focus_on_settings
bats_test_function --description "設定欄に on / off の状態を表示する" -- case_toggle_state_is_shown
bats_test_function --description "選んでいる候補の配色をその場で端末に反映する" -- case_preview_follows_selection
bats_test_function --description "列見出しと10行分の色見本を表示する" -- case_list_shows_labels_and_rows
bats_test_function --description "カーソルを選んでいる候補の行に置く" -- case_cursor_is_placed_on_selected_row
bats_test_function --description "カーソルを選んでいる設定の行に置く" -- case_cursor_is_placed_on_setting_row
bats_test_function --description "最初に空行と区切り線を表示する" -- case_starts_with_blank_line_and_frame
bats_test_function --description "一覧にカラーコードを表示しない" -- case_no_color_codes_in_list
bats_test_function --description "Esc で保存せずに終わり、元の配色に戻す" -- case_esc_cancels_and_restores
bats_test_function --description "Esc で親の .peacock の配色に戻す" -- case_esc_restores_parent_settings
bats_test_function --description "Ctrl+D でも保存せずに終わる" -- case_ctrl_d_cancels
bats_test_function --description "Ctrl+C でも保存せずに終わり、元の配色に戻す" -- case_ctrl_c_cancels_and_restores
bats_test_function --description "既存の .peacock の他の行を残す" -- case_keeps_other_lines
bats_test_function --description "cmd <command> set <pattern> で ini のセクションに保存する" -- case_section_enter_saves_into_ini
bats_test_function --description "セクションへの保存で他のセクションとコメントを残す" -- case_section_keeps_the_rest_of_the_file
bats_test_function --description "セクションでは Badge の既定の文字がパターンになる" -- case_section_badge_defaults_to_pattern
bats_test_function --description "セクションへの保存も Esc で書き込まない" -- case_section_cancel_writes_nothing
bats_test_function --description "cmd <command> set はパターンがなければ失敗する" -- case_section_requires_a_pattern
bats_test_function --description "端末でなければエラーにする" -- case_requires_terminal
bats_test_function --description "同じディレクトリ名なら同じ候補から始まる" -- case_same_dir_name_same_start
bats_test_function --description "1つの一覧に同じ候補が並ばない" -- case_list_has_no_duplicates
bats_test_function --description "候補は暗い背景と読みやすい文字色になる" -- case_candidates_are_readable
bats_test_function --description "端末が処理中に届いた ↓ は捨てる" -- case_sync_drops_keys_while_terminal_is_busy
bats_test_function --description "端末が処理中でも Esc で即座にやめる" -- case_sync_esc_while_terminal_is_busy
bats_test_function --description "端末が処理中に押した Enter は処理後に保存する" -- case_sync_enter_while_terminal_is_busy
bats_test_function --description "描き直すたびに DSR で端末の処理完了を確かめる" -- case_sync_sends_dsr_after_each_draw
bats_test_function --description "DSR に応答しない端末では同期しない" -- case_no_sync_without_reply
