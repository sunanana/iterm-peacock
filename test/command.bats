#!/usr/bin/env bats
# コマンド連動の挙動テスト。
# 各ケースはシェル名を引数に取る関数として書き、末尾で bash / zsh の両方に登録する。

load test_helper

setup() {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p config
  export PEACOCK_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
}

# 偽のコマンドを PATH の先に置く。引数をそのまま出力して終わる
fake_command() {
  local name
  mkdir -p fakebin
  for name in "$@"; do
    cat > "fakebin/$name" <<'EOF'
#!/bin/sh
printf 'FAKE %s\n' "$*"
exit "${FAKE_STATUS:-0}"
EOF
    chmod +x "fakebin/$name"
  done
  export PATH="$BATS_TEST_TMPDIR/fakebin:$PATH"
}

case_section_paints() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01'
  [ "$status" -eq 0 ]
  [ "$output" = "$(bg_seq 300000)$(badge_seq csw01)$(tab_seq 300000)" ]
}

case_first_matching_section_wins() {
  printf '[*]\nbackground=#111111\n\n[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01'
  [[ "$output" == *"$(bg_seq 111111)"* ]]
  [[ "$output" != *"$(bg_seq 300000)"* ]]
}

case_section_accepts_several_patterns() {
  printf '[csw* lms* pi?]\nbackground=#300000\n' > config/ssh.ini
  local host
  for host in lms99 pi4; do
    run_hook "$1" "_peacock_enter ssh $host"
    [[ "$output" == *"$(bg_seq 300000)"* ]]
  done
}

case_unmatched_keeps_directory_colors() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  echo 'background=#003366' > .peacock
  run_hook "$1" '_peacock_apply; printf SEP; _peacock_enter ssh other'
  [ "${output#*SEP}" = "" ]
}

case_unmatched_paints_nothing() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh other'
  [ -z "$output" ]
}

case_missing_ini_paints_nothing() {
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  run_hook "$1" '_peacock_enter psql prod-db-01'
  [ -z "$output" ]
}

case_section_replaces_directory_settings() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  printf 'background=#003366\nforeground=#eeeeee\n' > .peacock
  run_hook "$1" '_peacock_apply; printf SEP; _peacock_enter ssh csw01'
  local after="${output#*SEP}"
  [[ "$after" == *"${ESC}]110${BEL}"* ]]
  [[ "$after" == *"$(bg_seq 300000)"* ]]
}

case_returning_restores_previous_colors() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  echo 'background=#003366' > .peacock
  run_hook "$1" '_peacock_apply; _peacock_enter ssh csw01; printf SEP; _peacock_precmd'
  local after="${output#*SEP}"
  [[ "$after" == *"$(bg_seq 003366)"* ]]
  [[ "$after" == *"${ESC}]1337;SetBadgeFormat=${BEL}"* ]]
}

case_returning_resets_to_profile_without_peacock() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01; printf SEP; _peacock_precmd'
  [ "${output#*SEP}" = "${ESC}]111${BEL}${ESC}]1337;SetBadgeFormat=${BEL}${ESC}]6;1;bg;*;default${BEL}" ]
}

case_section_badge_wins_over_matched_word() {
  printf '[csw*]\nbackground=#300000\nbadge=PRODUCTION\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01'
  [[ "$output" == *"$(badge_seq PRODUCTION)"* ]]
  [[ "$output" != *"$(badge_seq csw01)"* ]]
}

case_badge_can_be_turned_off() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" 'PEACOCK_COMMAND_BADGE=0; _peacock_enter ssh csw01'
  [[ "$output" != *'SetBadgeFormat'* ]]
}

case_lines_before_first_section_are_ignored() {
  printf 'background=#003366\n\n[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01'
  [[ "$output" == *"$(bg_seq 300000)"* ]]
  [[ "$output" != *"$(bg_seq 003366)"* ]]
}

case_section_accepts_bare_color_and_comments() {
  printf '# production\n[csw*]\n#300000  # dark red\ncursor-guide=on\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01'
  [[ "$output" == *"$(bg_seq 300000)"* ]]
  [[ "$output" == *"${ESC}]1337;HighlightCursorLine=yes${BEL}"* ]]
}

case_next_section_ends_the_matched_one() {
  printf '[csw*]\nbackground=#300000\n\n[pi*]\nforeground=#eeeeee\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01'
  [[ "$output" != *"${ESC}]10;"* ]]
}

case_matches_a_word_anywhere_on_the_line() {
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  run_hook "$1" '_peacock_enter mysql -h prod-db-01 -u app mydb'
  [[ "$output" == *"$(bg_seq 300000)"* ]]
  [[ "$output" == *"$(badge_seq prod-db-01)"* ]]
}

case_matches_inside_a_connection_url() {
  printf '[*prod-db-01*]\nbackground=#300000\n' > config/psql.ini
  run_hook "$1" '_peacock_enter psql postgres://user@prod-db-01/app'
  [[ "$output" == *"$(bg_seq 300000)"* ]]
}

case_option_names_are_not_matched() {
  printf '[-h --host]\nbackground=#300000\n' > config/mysql.ini
  run_hook "$1" '_peacock_enter mysql -h prod-db-01'
  [ -z "$output" ]
}

case_command_name_is_not_matched() {
  printf '[mysql]\nbackground=#300000\n' > config/mysql.ini
  run_hook "$1" '_peacock_enter mysql mydb'
  [ -z "$output" ]
}

case_earlier_section_wins_over_later_word() {
  printf '[mydb]\nbackground=#111111\n\n[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  run_hook "$1" '_peacock_enter mysql -h prod-db-01 mydb'
  [[ "$output" == *"$(bg_seq 111111)"* ]]
  [[ "$output" == *"$(badge_seq mydb)"* ]]
}

case_command_name_skips_prefixes() {
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  local words
  for words in 'mysql -h prod-db-01' '/usr/local/bin/mysql -h prod-db-01' \
    'command mysql -h prod-db-01' 'LANG=C mysql -h prod-db-01'; do
    run_hook "$1" "_peacock_enter $words"
    [[ "$output" == *"$(bg_seq 300000)"* ]]
  done
}

case_ssh_matches_only_the_destination() {
  printf '[app]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh -l app myhost'
  [ -z "$output" ]
}

case_ssh_ignores_remote_command() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run_hook "$1" '_peacock_enter ssh csw01 ls'
  [ -z "$output" ]
}

case_target_plain_host() {
  run_hook "$1" 'host=; _peacock_ssh_target myhost && printf %s "$host"'
  [ "$output" = myhost ]
}

case_target_strips_user() {
  run_hook "$1" 'host=; _peacock_ssh_target user@myhost && printf %s "$host"'
  [ "$output" = myhost ]
}

case_target_skips_option_values() {
  run_hook "$1" 'host=; _peacock_ssh_target -p 2222 -o StrictHostKeyChecking=no myhost && printf %s "$host"'
  [ "$output" = myhost ]
}

case_target_skips_attached_option_values() {
  run_hook "$1" 'host=; _peacock_ssh_target -p2222 myhost && printf %s "$host"'
  [ "$output" = myhost ]
}

case_target_skips_bundled_flags() {
  run_hook "$1" 'host=; _peacock_ssh_target -4tp 2222 myhost && printf %s "$host"'
  [ "$output" = myhost ]
}

case_target_accepts_ssh_url() {
  run_hook "$1" 'host=; _peacock_ssh_target ssh://user@myhost:2222 && printf %s "$host"'
  [ "$output" = myhost ]
}

case_target_rejects_sessionless_options() {
  local flag
  for flag in -N -f -G -O -W; do
    run_hook "$1" "_peacock_ssh_target $flag myhost"
    [ "$status" -ne 0 ]
  done
}

case_target_rejects_missing_host() {
  run_hook "$1" '_peacock_ssh_target -p 2222'
  [ "$status" -ne 0 ]
}

case_wrapper_paints_and_restores() {
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  fake_command mysql
  run_hook "$1" '_peacock_wrap mysql -h prod-db-01'
  [ "$status" -eq 0 ]
  [[ "$output" == "$(bg_seq 300000)"*'FAKE -h prod-db-01'*"${ESC}]111${BEL}"* ]]
}

case_wrapper_keeps_exit_status() {
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  fake_command mysql
  run_hook "$1" 'FAKE_STATUS=3 _peacock_wrap mysql -h prod-db-01'
  [ "$status" -eq 3 ]
}

case_wrapper_leaves_unmatched_alone() {
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  fake_command mysql
  run_hook "$1" '_peacock_wrap mysql -h dev-db'
  [ "$status" -eq 0 ]
  [ "$output" = 'FAKE -h dev-db' ]
}

case_wrap_commands_hooks_every_ini() {
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  printf '[prod-db-*]\nbackground=#000030\n' > config/mysql.ini
  fake_command ssh mysql
  run_hook "$1" '_peacock_wrap_commands; mysql -h prod-db-01; _PEACOCK_CMD=; _PEACOCK_TARGET=; _peacock_apply; ssh csw01'
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 000030)"*'FAKE -h prod-db-01'*"$(bg_seq 300000)"*'FAKE csw01'* ]]
}

case_wrap_commands_skips_unusable_names() {
  printf '[csw*]\nbackground=#300000\n' > 'config/not a command.ini'
  run_hook "$1" '_peacock_wrap_commands; printf done'
  [ "$status" -eq 0 ]
  [ "$output" = done ]
}

case_wrap_commands_without_config_dir() {
  rm -r config
  run_hook "$1" '_peacock_wrap_commands; printf done'
  [ "$status" -eq 0 ]
  [ "$output" = done ]
}

for shell in bash zsh; do
  bats_test_function --description "[$shell] 当てはまるセクションの配色を適用する" -- case_section_paints "$shell"
  bats_test_function --description "[$shell] 当てはまる最初のセクションを使う" -- case_first_matching_section_wins "$shell"
  bats_test_function --description "[$shell] セクションに複数のパターンを書ける" -- case_section_accepts_several_patterns "$shell"
  bats_test_function --description "[$shell] 当てはまらなければディレクトリの配色のまま" -- case_unmatched_keeps_directory_colors "$shell"
  bats_test_function --description "[$shell] 当てはまらなければ何も出力しない" -- case_unmatched_paints_nothing "$shell"
  bats_test_function --description "[$shell] 設定ファイルのないコマンドは対象にしない" -- case_missing_ini_paints_nothing "$shell"
  bats_test_function --description "[$shell] ディレクトリの設定を置き換える" -- case_section_replaces_directory_settings "$shell"
  bats_test_function --description "[$shell] 戻ると .peacock の配色に戻る" -- case_returning_restores_previous_colors "$shell"
  bats_test_function --description "[$shell] .peacock がなければプロファイルの色に戻る" -- case_returning_resets_to_profile_without_peacock "$shell"
  bats_test_function --description "[$shell] セクションの badge は当てはまった語より優先する" -- case_section_badge_wins_over_matched_word "$shell"
  bats_test_function --description "[$shell] PEACOCK_COMMAND_BADGE=0 でバッジを出さない" -- case_badge_can_be_turned_off "$shell"
  bats_test_function --description "[$shell] セクションより前の行を無視する" -- case_lines_before_first_section_are_ignored "$shell"
  bats_test_function --description "[$shell] セクション内の色だけの行とコメントを解釈する" -- case_section_accepts_bare_color_and_comments "$shell"
  bats_test_function --description "[$shell] 次のセクションで読み取りを終える" -- case_next_section_ends_the_matched_one "$shell"
  bats_test_function --description "[$shell] 行のどの語でも当てはめる" -- case_matches_a_word_anywhere_on_the_line "$shell"
  bats_test_function --description "[$shell] 接続 URL の中の文字列にも当てはめる" -- case_matches_inside_a_connection_url "$shell"
  bats_test_function --description "[$shell] オプション名は照合しない" -- case_option_names_are_not_matched "$shell"
  bats_test_function --description "[$shell] コマンド名は照合しない" -- case_command_name_is_not_matched "$shell"
  bats_test_function --description "[$shell] 先に書いたセクションが後ろの語より優先する" -- case_earlier_section_wins_over_later_word "$shell"
  bats_test_function --description "[$shell] パス付き・command・環境変数の前置きを受け付ける" -- case_command_name_skips_prefixes "$shell"
  bats_test_function --description "[$shell] ssh は接続先だけを照合する" -- case_ssh_matches_only_the_destination "$shell"
  bats_test_function --description "[$shell] ssh はリモートコマンド付きを対象にしない" -- case_ssh_ignores_remote_command "$shell"
  bats_test_function --description "[$shell] 接続先を取り出す" -- case_target_plain_host "$shell"
  bats_test_function --description "[$shell] user@ を落として接続先を取り出す" -- case_target_strips_user "$shell"
  bats_test_function --description "[$shell] 値を取るオプションを読み飛ばす" -- case_target_skips_option_values "$shell"
  bats_test_function --description "[$shell] 値が続いたオプションを読み飛ばす" -- case_target_skips_attached_option_values "$shell"
  bats_test_function --description "[$shell] まとめて書いたフラグを読み飛ばす" -- case_target_skips_bundled_flags "$shell"
  bats_test_function --description "[$shell] ssh:// 形式から接続先を取り出す" -- case_target_accepts_ssh_url "$shell"
  bats_test_function --description "[$shell] シェルを取らないオプションは対象にしない" -- case_target_rejects_sessionless_options "$shell"
  bats_test_function --description "[$shell] 接続先がなければ失敗する" -- case_target_rejects_missing_host "$shell"
  bats_test_function --description "[$shell] ラッパーは実行の前後で塗り替えと復帰をする" -- case_wrapper_paints_and_restores "$shell"
  bats_test_function --description "[$shell] ラッパーは終了ステータスを返す" -- case_wrapper_keeps_exit_status "$shell"
  bats_test_function --description "[$shell] ラッパーは当てはまらなければ色を変えない" -- case_wrapper_leaves_unmatched_alone "$shell"
  bats_test_function --description "[$shell] 設定ファイルのあるコマンドを一通り包む" -- case_wrap_commands_hooks_every_ini "$shell"
  bats_test_function --description "[$shell] 関数名にできないファイル名を読み飛ばす" -- case_wrap_commands_skips_unusable_names "$shell"
  bats_test_function --description "[$shell] 設定ディレクトリがなくても失敗しない" -- case_wrap_commands_without_config_dir "$shell"
done
