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
}

case_help_topics() {
  local topic
  for topic in config picker; do
    run "$BIN" help "$topic"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

case_help_unknown_topic() {
  run "$BIN" help nope
  [ "$status" -eq 1 ]
  [[ "$output" == *'config, picker'* ]]
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
bats_test_function --description "シンボリックリンク経由でも動く" -- case_works_through_symlink
bats_test_function --description "--help で使い方とキーを表示する" -- case_help
bats_test_function --description "help <topic> で詳細を表示する" -- case_help_topics
bats_test_function --description "help は知らないトピックを拒否する" -- case_help_unknown_topic
bats_test_function --description "不明なコマンドは失敗する" -- case_unknown_command
