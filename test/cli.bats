#!/usr/bin/env bats
# CLI の挙動テスト。
# 日本語のテスト名を使うため、@test ではなく関数を bats_test_function で登録している。

load test_helper

case_set_writes_normalized_color() {
  run "$BIN" set '#ABC'
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'background=#aabbcc' ]
}

case_set_accepts_color_without_hash() {
  run "$BIN" set 003366
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'background=#003366' ]
}

case_set_key_value() {
  run "$BIN" set foreground EEE
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'foreground=#eeeeee' ]
}

case_set_badge_with_spaces() {
  run "$BIN" set badge My Project
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'badge=My Project' ]
}

case_set_normalizes_cursor_guide() {
  run "$BIN" set cursor-guide on
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'cursor-guide=yes' ]
}

case_set_replaces_in_place() {
  printf '# project\nbackground=#330000\nforeground=#eeeeee\n' > .peacock
  run "$BIN" set '#000033'
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = $'# project\nbackground=#000033\nforeground=#eeeeee' ]
}

case_set_replaces_bare_color_line() {
  printf '#330000\nforeground=#eeeeee\n' > .peacock
  run "$BIN" set '#000033'
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = $'background=#000033\nforeground=#eeeeee' ]
}

case_set_removes_duplicates() {
  printf 'red=#110000\nred=#220000\n' > .peacock
  run "$BIN" set red '#330000'
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'red=#330000' ]
}

case_set_appends_new_key() {
  printf '# project\nbackground=#330000\n' > .peacock
  run "$BIN" set badge PROD
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = $'# project\nbackground=#330000\nbadge=PROD' ]
}

case_set_rejects_invalid_color() {
  run "$BIN" set navy
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid value for background: 'navy'"* ]]
  [ ! -e .peacock ]
}

case_set_rejects_unknown_key() {
  run "$BIN" set bold '#ffffff'
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown key 'bold'"* ]]
  [ ! -e .peacock ]
}

case_set_requires_value() {
  run "$BIN" set
  [ "$status" -eq 1 ]
  [ ! -e .peacock ]
}

case_status_shows_settings_and_source() {
  printf 'background=#003366\nbadge=PROD\n' > .peacock
  mkdir -p sub
  cd sub
  run "$BIN" show
  [ "$status" -eq 0 ]
  [ "$output" = $'# '"$BATS_TEST_TMPDIR"$'/.peacock\nbackground=#003366\nbadge=PROD\ntab=#003366' ]
}

case_status_reads_bare_color_line() {
  echo '#ABC' > .peacock
  run "$BIN" show
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nbackground=#aabbcc'* ]]
}

case_status_warns_ignored_lines() {
  printf '# comment\nbackground=#003366\nbold=#ffffff\n' > .peacock
  run "$BIN" show
  [ "$status" -eq 0 ]
  [[ "$output" == *'iterm-peacock: ignored: bold=#ffffff'* ]]
  [[ "$output" != *'ignored: # comment'* ]]
}

case_status_without_peacock() {
  run "$BIN" show
  [ "$status" -eq 0 ]
  [ "$output" = 'no .peacock' ]
}

case_status_reports_unreadable_file() {
  echo 'background=navy' > .peacock
  run "$BIN" show
  [ "$status" -eq 1 ]
  [[ "$output" == *"no valid settings in"* ]]
}

case_where_prints_nearest_path() {
  echo 'background=#003366' > .peacock
  mkdir -p a/b
  cd a/b
  run "$BIN" where
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/.peacock" ]
}

case_where_fails_without_peacock() {
  run "$BIN" where
  [ "$status" -eq 1 ]
}

case_unset_removes_file() {
  echo 'background=#003366' > .peacock
  run "$BIN" unset
  [ "$status" -eq 0 ]
  [ ! -e .peacock ]
}

case_unset_key() {
  printf '# project\nbackground=#003366\nred=#ff0000\n' > .peacock
  run "$BIN" unset red
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = $'# project\nbackground=#003366' ]
}

case_unset_bare_color_as_background() {
  printf '#003366\nred=#ff0000\n' > .peacock
  run "$BIN" unset background
  [ "$status" -eq 0 ]
  [ "$(cat .peacock)" = 'red=#ff0000' ]
}

case_unset_last_key_removes_file() {
  echo 'red=#ff0000' > .peacock
  run "$BIN" unset red
  [ "$status" -eq 0 ]
  [ ! -e .peacock ]
}

case_unset_missing_key_fails() {
  echo 'background=#003366' > .peacock
  run "$BIN" unset red
  [ "$status" -eq 1 ]
  [[ "$output" == *"no red in"* ]]
  [ "$(cat .peacock)" = 'background=#003366' ]
}

case_unset_only_touches_current_dir() {
  echo 'background=#003366' > .peacock
  mkdir -p sub
  cd sub
  run "$BIN" unset
  [ "$status" -eq 1 ]
  [ -f ../.peacock ]
}

case_cmd_lists_commands_and_sections() {
  mkdir -p config
  printf '# hosts\n[csw* lms*]\nbackground=#300000\n\n[pi*]\nbackground=#293220\n' > config/ssh.ini
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd
  [ "$status" -eq 0 ]
  [ "$output" = $'# '"$PWD"$'/config\nmysql\n  [prod-db-*]\nssh\n  [csw* lms*]\n  [pi*]' ]
}

case_cmd_list_is_the_same_as_no_argument() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd list
  [ "$status" -eq 0 ]
  [ "$output" = $'# '"$PWD"$'/config\nmysql\n  [prod-db-*]' ]
}

case_cmd_show_is_the_same_as_the_bare_word() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql show prod-db-01
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\n[prod-db-*]\nbackground=#300000'* ]]
}

case_cmd_set_key_creates_file_and_section() {
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' background '#ABC'
  [ "$status" -eq 0 ]
  [[ "$output" == *"background=#aabbcc -> $PWD/config/mysql.ini [prod-db-*]"* ]]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\nbackground=#aabbcc' ]
}

case_cmd_set_key_is_idempotent() {
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' background '#300000'
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' background '#300000'
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\nbackground=#300000' ]
}

case_cmd_set_key_replaces_in_place() {
  mkdir -p config
  printf '# hosts\n[prod-db-*]\nbackground=#300000\nbadge=PRODUCTION\n\n[staging-db-*]\nbackground=#000030\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' background '#3a0000'
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'# hosts\n[prod-db-*]\nbackground=#3a0000\nbadge=PRODUCTION\n\n[staging-db-*]\nbackground=#000030' ]
}

case_cmd_set_key_adds_a_section_to_an_existing_file() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'staging-db-*' background '#000030'
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\nbackground=#300000\n\n[staging-db-*]\nbackground=#000030' ]
}

case_cmd_set_badge_with_spaces() {
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' badge My Project
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\nbadge=My Project' ]
}

case_cmd_set_rejects_unknown_key_and_value() {
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' bold '#ffffff'
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown key 'bold'"* ]]
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set 'prod-db-*' background navy
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid value for background: 'navy'"* ]]
  [ ! -e config/mysql.ini ]
}

case_cmd_unset_key() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\nbadge=PRODUCTION\n\n[staging-db-*]\nbackground=#000030\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset 'prod-db-*' badge
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\nbackground=#300000\n\n[staging-db-*]\nbackground=#000030' ]
}

case_cmd_unset_last_key_removes_the_section() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n\n[staging-db-*]\nbackground=#000030\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset 'prod-db-*' background
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'[staging-db-*]\nbackground=#000030' ]
}

case_cmd_unset_section() {
  mkdir -p config
  printf '# hosts\n[prod-db-*]\nbackground=#300000\n\n[staging-db-*]\nbackground=#000030\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset 'staging-db-*'
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'# hosts\n[prod-db-*]\nbackground=#300000' ]
}

case_cmd_unset_last_section_removes_the_file() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset 'prod-db-*'
  [ "$status" -eq 0 ]
  [ ! -e config/mysql.ini ]
}

case_cmd_unset_removes_the_file() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset
  [ "$status" -eq 0 ]
  [ ! -e config/mysql.ini ]
}

case_cmd_unset_missing_section_and_key_fail() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset 'staging-db-*'
  [ "$status" -eq 1 ]
  [[ "$output" == *'no [staging-db-*] in'* ]]
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset 'prod-db-*' badge
  [ "$status" -eq 1 ]
  [[ "$output" == *'no badge in'* ]]
  [ "$(cat config/mysql.ini)" = $'[prod-db-*]\nbackground=#300000' ]
}

case_cmd_edit_opens_the_file() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  EDITOR='echo opened' PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql edit
  [ "$status" -eq 0 ]
  [ "$output" = "opened $PWD/config/mysql.ini" ]
}

case_cmd_edit_prefers_visual() {
  VISUAL='echo visual' EDITOR='echo editor' PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql edit
  [ "$status" -eq 0 ]
  [[ "$output" == visual* ]]
  [ -d config ]
}

case_cmd_edit_without_editor_fails() {
  VISUAL= EDITOR= PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql edit
  [ "$status" -eq 1 ]
  [[ "$output" == *'set $VISUAL or $EDITOR'* ]]
}

case_cmd_lists_one_commands_sections() {
  mkdir -p config
  printf '[csw* lms*]\nbackground=#300000\n\n[pi*]\nbackground=#293220\n' > config/ssh.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd ssh
  [ "$status" -eq 0 ]
  [ "$output" = $'# '"$PWD"$'/config/ssh.ini\n[csw* lms*]\n[pi*]' ]
}

case_cmd_shows_settings_for_word() {
  mkdir -p config
  printf '[prod-db-* *.prod.example.com]\nbackground=#300000\nbadge=PRODUCTION\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql prod-db-01
  [ "$status" -eq 0 ]
  [ "$output" = $'# '"$PWD"$'/config/mysql.ini\n[prod-db-* *.prod.example.com]\nbackground=#300000\nbadge=PRODUCTION\ntab=#300000' ]
}

case_cmd_adds_matched_word_as_badge() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql prod-db-01
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nbadge=prod-db-01'* ]]
}

case_cmd_reports_unmatched_word() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql dev-db
  [ "$status" -eq 1 ]
  [[ "$output" == *"no section matches 'dev-db'"* ]]
}

case_cmd_reports_command_without_settings() {
  mkdir -p config
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd psql
  [ "$status" -eq 1 ]
  [[ "$output" == *"no settings for 'psql' at"* ]]
}

case_cmd_reports_empty_config_dir() {
  mkdir -p config
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd
  [ "$status" -eq 1 ]
  [[ "$output" == *'no <command>.ini in'* ]]
}

case_cmd_warns_lines_outside_sections() {
  mkdir -p config
  printf '# hosts\nbackground=#003366\n[csw*]\nbold=#ffffff\n' > config/ssh.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd ssh
  [ "$status" -eq 0 ]
  [[ "$output" == *'ignored (before the first section): background=#003366'* ]]
  [[ "$output" == *'ignored: bold=#ffffff'* ]]
  [[ "$output" != *'ignored: # hosts'* ]]
}

case_cmd_does_not_read_peacock() {
  mkdir -p config
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  echo 'background=#003366' > .peacock
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd ssh csw01
  [ "$status" -eq 0 ]
  [[ "$output" != *'#003366'* ]]
}

tunnel_ini() {
  mkdir -p config
  printf '[PROD]\nmatch-options = -h|--host=127.0.0.1 -P|--port=13306\nbackground=#300000\n\n' > config/mysql.ini
  printf '[STAGING]\nmatch-options = -h|--host=127.0.0.1 -P|--port=13307\nbackground=#000030\n' >> config/mysql.ini
}

case_cmd_test_shows_the_winning_section() {
  tunnel_ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql test -h 127.0.0.1 -P 13306 -u eng -p
  [ "$status" -eq 0 ]
  [ "$output" = $'# '"$PWD"$'/config/mysql.ini\n[PROD]\nbackground=#300000\nbadge=PROD\ntab=#300000' ]
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql test --host=127.0.0.1 --port=13307
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\n[STAGING]\n'* ]]
}

case_cmd_test_reports_unmatched_command_line() {
  tunnel_ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql test -h 127.0.0.1
  [ "$status" -eq 1 ]
  [[ "$output" == *'no section matches: mysql -h 127.0.0.1'* ]]
}

case_cmd_test_explains_ssh_without_terminal() {
  mkdir -p config
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd ssh test csw01 ls
  [ "$status" -eq 1 ]
  [[ "$output" == *'ssh csw01 ls is left alone'* ]]
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd ssh test -N -L 8080:localhost:80 csw01
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\n[csw*]\n'* ]]
}

case_cmd_set_match_options_normalizes_spaces() {
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set PROD match-options ' -h=127.0.0.1   -P|--port=13306 '
  [ "$status" -eq 0 ]
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set PROD background '#300000'
  [ "$(cat config/mysql.ini)" = $'[PROD]\nmatch-options=-h=127.0.0.1 -P|--port=13306\nbackground=#300000' ]
}

case_cmd_set_rejects_unreadable_match_options() {
  local value
  for value in '-P' '-P=' '-P||--port=1' '-P|=1' '--=1' ''; do
    PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql set PROD match-options "$value"
    [ "$status" -eq 1 ]
  done
  [ ! -e config/mysql.ini ]
}

case_cmd_unset_match_options() {
  tunnel_ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql unset PROD match-options
  [ "$status" -eq 0 ]
  [ "$(cat config/mysql.ini)" = $'[PROD]\nbackground=#300000\n\n[STAGING]\nmatch-options = -h|--host=127.0.0.1 -P|--port=13307\nbackground=#000030' ]
}

case_cmd_warns_unreadable_match_options() {
  mkdir -p config
  printf '[PROD]\nmatch-options = -P\nbackground=#300000\n' > config/mysql.ini
  PEACOCK_CONFIG_DIR="$PWD/config" run "$BIN" cmd mysql
  [ "$status" -eq 0 ]
  [[ "$output" == *'unreadable match-options, the section never matches: match-options = -P'* ]]
}

case_set_rejects_match_options_in_peacock() {
  run "$BIN" set match-options '-P=13306'
  [ "$status" -eq 1 ]
  [ ! -e .peacock ]
  printf 'match-options=-P=13306\nbackground=#003366\n' > .peacock
  run "$BIN" show
  [[ "$output" == *'ignored: match-options=-P=13306'* ]]
}

case_works_through_symlink() {
  mkdir -p bin
  ln -s "$BIN" bin/iterm-peacock
  echo 'background=#003366' > .peacock
  run bin/iterm-peacock show
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nbackground=#003366'* ]]
}

case_help() {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'iterm-peacock set <key> <value>'* ]]
  [[ "$output" == *'cursor-guide'* ]]
  [[ "$output" == *'iterm-peacock help config'* ]]
  [[ "$output" == *'iterm-peacock update'* ]]
  [[ "$output" == *'ask them to run it in their own terminal'* ]]
}

case_help_topics() {
  local topic
  for topic in config picker cmd; do
    run "$BIN" help "$topic"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

case_help_unknown_topic() {
  run "$BIN" help nope
  [ "$status" -eq 1 ]
  [[ "$output" == *'config, picker, cmd'* ]]
}

case_unknown_command() {
  run "$BIN" paint
  [ "$status" -eq 1 ]
}

bats_test_function --description "set は色を正規化して background に書く" -- case_set_writes_normalized_color
bats_test_function --description "set は # なしの色も受け付ける" -- case_set_accepts_color_without_hash
bats_test_function --description "set <key> <value> で任意のキーを書く" -- case_set_key_value
bats_test_function --description "set badge は空白を含む文字をそのまま書く" -- case_set_badge_with_spaces
bats_test_function --description "set cursor-guide は yes / no に正規化する" -- case_set_normalizes_cursor_guide
bats_test_function --description "set は既存の行をその位置で置き換える" -- case_set_replaces_in_place
bats_test_function --description "set は色だけの行も background として置き換える" -- case_set_replaces_bare_color_line
bats_test_function --description "set は同じキーの重複行をまとめる" -- case_set_removes_duplicates
bats_test_function --description "set は新しいキーを末尾に足す" -- case_set_appends_new_key
bats_test_function --description "set は色として読めない値を拒否する" -- case_set_rejects_invalid_color
bats_test_function --description "set は未対応のキーを拒否する" -- case_set_rejects_unknown_key
bats_test_function --description "set は値がなければ失敗する" -- case_set_requires_value
bats_test_function --description "show は設定と出どころを表示する" -- case_status_shows_settings_and_source
bats_test_function --description "show は色だけの行も読める" -- case_status_reads_bare_color_line
bats_test_function --description "show は解釈できない行を警告する" -- case_status_warns_ignored_lines
bats_test_function --description "show は .peacock がないことを表示する" -- case_status_without_peacock
bats_test_function --description "show は有効な設定のない .peacock を報告する" -- case_status_reports_unreadable_file
bats_test_function --description "where は一番近い .peacock のパスを表示する" -- case_where_prints_nearest_path
bats_test_function --description "where は .peacock がなければ失敗する" -- case_where_fails_without_peacock
bats_test_function --description "unset は .peacock を削除する" -- case_unset_removes_file
bats_test_function --description "unset <key> はそのキーの行だけを消す" -- case_unset_key
bats_test_function --description "unset background は色だけの行も消す" -- case_unset_bare_color_as_background
bats_test_function --description "unset <key> で最後のキーを消すとファイルも消す" -- case_unset_last_key_removes_file
bats_test_function --description "unset <key> はキーがなければ失敗する" -- case_unset_missing_key_fails
bats_test_function --description "unset は親ディレクトリの .peacock を消さない" -- case_unset_only_touches_current_dir
bats_test_function --description "cmd は設定のあるコマンドとセクションを一覧する" -- case_cmd_lists_commands_and_sections
bats_test_function --description "cmd list は引数なしと同じ一覧を出す" -- case_cmd_list_is_the_same_as_no_argument
bats_test_function --description "cmd <command> show <word> は語だけを渡すのと同じ" -- case_cmd_show_is_the_same_as_the_bare_word
bats_test_function --description "cmd <command> set <pattern> <key> <value> はファイルとセクションを作る" -- case_cmd_set_key_creates_file_and_section
bats_test_function --description "cmd set は何度実行しても同じ内容になる" -- case_cmd_set_key_is_idempotent
bats_test_function --description "cmd set は既存の行をその位置で置き換える" -- case_cmd_set_key_replaces_in_place
bats_test_function --description "cmd set は既存のファイルにセクションを足す" -- case_cmd_set_key_adds_a_section_to_an_existing_file
bats_test_function --description "cmd set badge は空白を含む文字をそのまま書く" -- case_cmd_set_badge_with_spaces
bats_test_function --description "cmd set は未対応のキーと読めない値を拒否する" -- case_cmd_set_rejects_unknown_key_and_value
bats_test_function --description "cmd unset <pattern> <key> はそのキーだけを消す" -- case_cmd_unset_key
bats_test_function --description "cmd unset で最後のキーを消すとセクションも消える" -- case_cmd_unset_last_key_removes_the_section
bats_test_function --description "cmd unset <pattern> はセクションを消す" -- case_cmd_unset_section
bats_test_function --description "cmd unset で最後のセクションを消すとファイルも消える" -- case_cmd_unset_last_section_removes_the_file
bats_test_function --description "cmd <command> unset はファイルを消す" -- case_cmd_unset_removes_the_file
bats_test_function --description "cmd unset はないセクション・ないキーで失敗する" -- case_cmd_unset_missing_section_and_key_fail
bats_test_function --description "cmd <command> edit はエディタでファイルを開く" -- case_cmd_edit_opens_the_file
bats_test_function --description "cmd edit は VISUAL を EDITOR より優先する" -- case_cmd_edit_prefers_visual
bats_test_function --description "cmd edit は EDITOR がなければ失敗する" -- case_cmd_edit_without_editor_fails
bats_test_function --description "cmd <command> はそのコマンドのセクションを一覧する" -- case_cmd_lists_one_commands_sections
bats_test_function --description "cmd <command> <word> はその語で効く設定を表示する" -- case_cmd_shows_settings_for_word
bats_test_function --description "cmd <command> <word> は badge がなければ語を出す" -- case_cmd_adds_matched_word_as_badge
bats_test_function --description "cmd <command> <word> は当てはまらなければ失敗する" -- case_cmd_reports_unmatched_word
bats_test_function --description "cmd <command> は設定ファイルがなければ失敗する" -- case_cmd_reports_command_without_settings
bats_test_function --description "cmd は設定ファイルが1つもなければ失敗する" -- case_cmd_reports_empty_config_dir
bats_test_function --description "cmd はセクション外の行と読めない行を警告する" -- case_cmd_warns_lines_outside_sections
bats_test_function --description "cmd <command> <word> は .peacock を混ぜない" -- case_cmd_does_not_read_peacock
bats_test_function --description "cmd <command> test はコマンド行で勝つセクションと設定を表示する" -- case_cmd_test_shows_the_winning_section
bats_test_function --description "cmd <command> test は当てはまらなければ失敗する" -- case_cmd_test_reports_unmatched_command_line
bats_test_function --description "cmd ssh test は端末を占有しない ssh を理由つきで失敗する" -- case_cmd_test_explains_ssh_without_terminal
bats_test_function --description "cmd set match-options は条件の区切りの空白を揃える" -- case_cmd_set_match_options_normalizes_spaces
bats_test_function --description "cmd set は読めない match-options を拒否する" -- case_cmd_set_rejects_unreadable_match_options
bats_test_function --description "cmd unset で match-options だけを消す" -- case_cmd_unset_match_options
bats_test_function --description "cmd は読めない match-options を警告する" -- case_cmd_warns_unreadable_match_options
bats_test_function --description ".peacock には match-options を書けない" -- case_set_rejects_match_options_in_peacock
bats_test_function --description "シンボリックリンク経由でも動く" -- case_works_through_symlink
bats_test_function --description "--help で使い方とキーを表示する" -- case_help
bats_test_function --description "help <topic> で詳細を表示する" -- case_help_topics
bats_test_function --description "help は知らないトピックを拒否する" -- case_help_unknown_topic
bats_test_function --description "不明なコマンドは失敗する" -- case_unknown_command
