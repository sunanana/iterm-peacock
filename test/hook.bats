#!/usr/bin/env bats
# シェルフックの挙動テスト。
# 各ケースはシェル名を引数に取る関数として書き、末尾で bash / zsh の両方に登録する。

load test_helper

case_no_peacock_outputs_nothing() {
  run_hook "$1" _peacock_apply
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

case_paints_background_and_tab() {
  echo 'background=#1a0a0a' > .peacock
  run_hook "$1" _peacock_apply
  [ "$status" -eq 0 ]
  [ "$output" = "${ESC}]11;rgb:1a/0a/0a${BEL}${ESC}]6;1;bg;red;brightness;26${BEL}${ESC}]6;1;bg;green;brightness;10${BEL}${ESC}]6;1;bg;blue;brightness;10${BEL}" ]
}

case_applies_parent_peacock_in_subdir() {
  echo 'background=#1a0a0a' > .peacock
  mkdir -p a/b
  run_hook "$1" "cd a/b; _peacock_apply"
  [[ "$output" == *"$(bg_seq 1a0a0a)"* ]]
}

case_nearest_peacock_wins() {
  echo 'background=#1a0a0a' > .peacock
  mkdir -p inner
  echo 'background=#003366' > inner/.peacock
  run_hook "$1" "cd inner; _peacock_apply"
  [[ "$output" == *"$(bg_seq 003366)"* ]]
}

case_accepts_bare_color_line() {
  echo '#003366' > .peacock
  run_hook "$1" _peacock_apply
  [[ "$output" == *"$(bg_seq 003366)"* ]]
}

case_accepts_short_and_uppercase_color() {
  echo 'background=#ABC' > .peacock
  run_hook "$1" _peacock_apply
  [[ "$output" == *"$(bg_seq aabbcc)"* ]]
}

case_ignores_comments() {
  printf '# project color\n\nbackground = #003366  # navy\n' > .peacock
  run_hook "$1" _peacock_apply
  [[ "$output" == *"$(bg_seq 003366)"* ]]
}

case_ignores_unsupported_keys() {
  printf 'bold=#ffffff\nlink=#ffffff\nunderline=#ffffff\nfoo=bar\nbackground=#003366\n' > .peacock
  run_hook "$1" _peacock_apply
  [ "$output" = "$(bg_seq 003366)${ESC}]6;1;bg;red;brightness;0${BEL}${ESC}]6;1;bg;green;brightness;51${BEL}${ESC}]6;1;bg;blue;brightness;102${BEL}" ]
}

case_first_duplicate_wins() {
  printf 'background=#003366\nbackground=#330000\n' > .peacock
  run_hook "$1" _peacock_apply
  [[ "$output" == *"$(bg_seq 003366)"* ]]
  [[ "$output" != *"$(bg_seq 330000)"* ]]
}

case_leaving_resets_only_applied_keys() {
  mkdir -p colored plain
  printf 'foreground=#eeeeee\nred=#ff0000\nbadge=PROD\n' > colored/.peacock
  run_hook "$1" "cd colored; _peacock_apply; printf SEP; cd ../plain; _peacock_apply"
  [[ "$output" == *"SEP${ESC}]110${BEL}${ESC}]104;1${BEL}${ESC}]1337;SetBadgeFormat=${BEL}" ]]
}

case_switching_resets_dropped_keys() {
  mkdir -p a b
  printf 'background=#330000\nforeground=#eeeeee\n' > a/.peacock
  echo 'background=#000033' > b/.peacock
  run_hook "$1" "cd a; _peacock_apply; printf SEP; cd ../b; _peacock_apply"
  local after="${output#*SEP}"
  [[ "$after" == *"${ESC}]110${BEL}"* ]]
  [[ "$after" == *"$(bg_seq 000033)"* ]]
  [[ "$after" != *"${ESC}]111${BEL}"* ]]
}

case_unchanged_keys_are_not_resent() {
  mkdir -p a b
  printf 'background=#330000\nforeground=#eeeeee\n' > a/.peacock
  printf 'background=#000033\nforeground=#eeeeee\n' > b/.peacock
  run_hook "$1" "cd a; _peacock_apply; printf SEP; cd ../b; _peacock_apply"
  local after="${output#*SEP}"
  [[ "$after" == *"$(bg_seq 000033)"* ]]
  [[ "$after" != *"${ESC}]10;"* ]]
}

case_invalid_color_is_treated_as_none() {
  echo 'background=navy' > .peacock
  run_hook "$1" _peacock_apply
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

case_same_color_is_not_repainted() {
  echo 'background=#1a0a0a' > .peacock
  mkdir -p sub
  run_hook "$1" "_peacock_apply; printf SEP; cd sub; _peacock_apply"
  [[ "$output" == *"$(bg_seq 1a0a0a)"*SEP ]]
}

case_leaving_resets_colors() {
  mkdir -p colored plain
  echo 'background=#1a0a0a' > colored/.peacock
  run_hook "$1" "cd colored; _peacock_apply; printf SEP; cd ../plain; _peacock_apply"
  [[ "$output" == *"SEP$RESET" ]]
}

case_switching_projects_repaints() {
  mkdir -p red blue
  echo 'background=#330000' > red/.peacock
  echo 'background=#000033' > blue/.peacock
  run_hook "$1" "cd red; _peacock_apply; printf SEP; cd ../blue; _peacock_apply"
  [[ "$output" == *"SEP$(bg_seq 000033)"* ]]
}

case_edited_peacock_is_repainted() {
  echo 'background=#330000' > .peacock
  run_hook "$1" "_peacock_apply; printf SEP; echo 'background=#000033' > .peacock; _peacock_apply"
  [[ "$output" == *"SEP$(bg_seq 000033)"* ]]
}

for shell in bash zsh; do
  bats_test_function --description "[$shell] .peacock がなければ何も出力しない" -- case_no_peacock_outputs_nothing "$shell"
  bats_test_function --description "[$shell] 背景色とタブ色のエスケープを出力する" -- case_paints_background_and_tab "$shell"
  bats_test_function --description "[$shell] サブディレクトリでも親の .peacock を使う" -- case_applies_parent_peacock_in_subdir "$shell"
  bats_test_function --description "[$shell] 一番近い .peacock を優先する" -- case_nearest_peacock_wins "$shell"
  bats_test_function --description "[$shell] 色だけを書いた行を受け付ける" -- case_accepts_bare_color_line "$shell"
  bats_test_function --description "[$shell] 3桁と大文字の色を正規化する" -- case_accepts_short_and_uppercase_color "$shell"
  bats_test_function --description "[$shell] コメント行と行末コメントを無視する" -- case_ignores_comments "$shell"
  bats_test_function --description "[$shell] 未対応のキーを無視する" -- case_ignores_unsupported_keys "$shell"
  bats_test_function --description "[$shell] 同じキーが複数あれば最初の行を使う" -- case_first_duplicate_wins "$shell"
  bats_test_function --description "[$shell] .peacock の外に出ると設定したキーだけを戻す" -- case_leaving_resets_only_applied_keys "$shell"
  bats_test_function --description "[$shell] 移動先にないキーは戻し、あるキーは設定する" -- case_switching_resets_dropped_keys "$shell"
  bats_test_function --description "[$shell] 値が変わらないキーは送り直さない" -- case_unchanged_keys_are_not_resent "$shell"
  bats_test_function --description "[$shell] 色として読めない値は未設定として扱う" -- case_invalid_color_is_treated_as_none "$shell"
  bats_test_function --description "[$shell] 同じ色が続くときは再出力しない" -- case_same_color_is_not_repainted "$shell"
  bats_test_function --description "[$shell] .peacock の外に出ると色を戻す" -- case_leaving_resets_colors "$shell"
  bats_test_function --description "[$shell] 別プロジェクトに移ると塗り直す" -- case_switching_projects_repaints "$shell"
  bats_test_function --description "[$shell] .peacock を書き換えると塗り直す" -- case_edited_peacock_is_repainted "$shell"
done

case_zsh_extendedglob() {
  printf '# project color\nbackground=#003366  # navy\n' > .peacock
  run zsh -f -c "setopt extendedglob; source '$HOOK'; _peacock_apply"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 003366)"* ]]
}

# @test に日本語の名前を付けると bats がテスト名を解決できないため、関数として登録している
bats_test_function --description "[zsh] EXTENDED_GLOB が有効でもコメントを解釈できる" -- case_zsh_extendedglob
