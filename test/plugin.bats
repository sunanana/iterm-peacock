#!/usr/bin/env bats
# zsh プラグインとして読み込んだときの挙動テスト。
# 日本語のテスト名を使うため、@test ではなく関数を bats_test_function で登録している。

load test_helper

# プロンプト表示直前に zsh が precmd を呼ぶ動きを再現する
RUN_PRECMD='for f in $precmd_functions; do $f; done'

case_registers_precmd() {
  run zsh -f -c "source '$PLUGIN'; print -l \$precmd_functions"
  [ "$status" -eq 0 ]
  [ "$output" = '_peacock_apply' ]
}

case_keeps_existing_precmd() {
  run zsh -f -c "precmd_functions=(my_precmd); source '$PLUGIN'; print -l \$precmd_functions"
  [ "$status" -eq 0 ]
  [ "$output" = $'my_precmd\n_peacock_apply' ]
}

case_adds_cli_to_path() {
  run zsh -f -c "source '$PLUGIN'; command -v iterm-peacock"
  [ "$status" -eq 0 ]
  [ "$output" = "$BIN" ]
}

case_sourcing_twice_does_not_duplicate() {
  run zsh -f -c "source '$PLUGIN'; source '$PLUGIN'; print \${#precmd_functions} \${#\${(M)path:#$REPO/bin}}"
  [ "$status" -eq 0 ]
  [ "$output" = '1 1' ]
}

case_paints_on_prompt() {
  echo 'background=#003366' > .peacock
  run zsh -f -c "source '$PLUGIN'; $RUN_PRECMD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 003366)"* ]]
}

case_follows_cd_between_prompts() {
  mkdir -p colored plain
  echo 'background=#003366' > colored/.peacock
  run zsh -f -c "source '$PLUGIN'; cd colored; $RUN_PRECMD; printf SEP; cd ../plain; $RUN_PRECMD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 003366)"*"SEP$RESET" ]]
}

case_works_via_relative_symlink() {
  mkdir -p plugins
  ln -s "$REPO" plugins/iterm-peacock
  echo 'background=#003366' > .peacock
  run zsh -f -c "source plugins/iterm-peacock/iterm-peacock.plugin.zsh; command -v iterm-peacock; $RUN_PRECMD"
  [ "$status" -eq 0 ]
  [[ "$output" == "$BIN"*"$(bg_seq 003366)"* ]]
}

case_works_when_sourced_in_function() {
  run zsh -f -c "load_plugin() { source '$PLUGIN'; }; load_plugin; print -l \$precmd_functions; command -v iterm-peacock"
  [ "$status" -eq 0 ]
  [ "$output" = $'_peacock_apply\n'"$BIN" ]
}

bats_test_function --description "precmd に _peacock_apply を登録する" -- case_registers_precmd
bats_test_function --description "既存の precmd 関数を残す" -- case_keeps_existing_precmd
bats_test_function --description "CLI を PATH に追加する" -- case_adds_cli_to_path
bats_test_function --description "2回 source しても登録が重複しない" -- case_sourcing_twice_does_not_duplicate
bats_test_function --description "プロンプト表示時に .peacock の色を塗る" -- case_paints_on_prompt
bats_test_function --description "cd に合わせて塗り替え・リセットする" -- case_follows_cd_between_prompts
bats_test_function --description "相対パスとシンボリックリンク経由でも読み込める" -- case_works_via_relative_symlink
bats_test_function --description "関数内で source されても動く" -- case_works_when_sourced_in_function
