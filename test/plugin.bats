#!/usr/bin/env bats
# zsh プラグインとして読み込んだときの挙動テスト。
# 日本語のテスト名を使うため、@test ではなく関数を bats_test_function で登録している。

load test_helper

# プロンプト表示直前に zsh が precmd を呼ぶ動きを再現する
RUN_PRECMD='for f in $precmd_functions; do $f; done'

# コマンド実行直前に zsh が preexec を呼ぶ動きを再現する。
# zsh は打った行・1行にまとめた行・展開後の行の3つを渡す
run_preexec() {
  printf 'for f in $preexec_functions; do $f %q %q %q; done' "$1" "$1" "$1"
}

case_registers_precmd() {
  run zsh -f -c "source '$PLUGIN'; print -l \$precmd_functions"
  [ "$status" -eq 0 ]
  [ "$output" = '_peacock_precmd' ]
}

case_registers_preexec() {
  run zsh -f -c "source '$PLUGIN'; print -l \$preexec_functions"
  [ "$status" -eq 0 ]
  [ "$output" = '_peacock_preexec' ]
}

case_command_hook_can_be_disabled() {
  run zsh -f -c "PEACOCK_COMMANDS=0; source '$PLUGIN'; print \${#preexec_functions} \${#precmd_functions}"
  [ "$status" -eq 0 ]
  [ "$output" = '0 1' ]
}

case_keeps_existing_precmd() {
  run zsh -f -c "precmd_functions=(my_precmd); source '$PLUGIN'; print -l \$precmd_functions"
  [ "$status" -eq 0 ]
  [ "$output" = $'my_precmd\n_peacock_precmd' ]
}

case_adds_cli_to_path() {
  run zsh -f -c "source '$PLUGIN'; command -v iterm-peacock"
  [ "$status" -eq 0 ]
  [ "$output" = "$BIN" ]
}

case_sourcing_twice_does_not_duplicate() {
  run zsh -f -c "source '$PLUGIN'; source '$PLUGIN'; print \${#precmd_functions} \${#preexec_functions} \${#\${(M)path:#$REPO/bin}}"
  [ "$status" -eq 0 ]
  [ "$output" = '1 1 1' ]
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
  [ "$output" = $'_peacock_precmd\n'"$BIN" ]
}

# 設定ファイルを置いたディレクトリを使わせる zsh の前置き
peacock_env() {
  mkdir -p config
  printf 'export PEACOCK_CONFIG_DIR=%s/config; ' "$PWD"
}

case_paints_on_hooked_command() {
  mkdir -p config
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run zsh -f -c "$(peacock_env) source '$PLUGIN'; $(run_preexec 'ssh csw01')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 300000)"* ]]
  [[ "$output" == *"$(badge_seq csw01)"* ]]
}

case_paints_on_any_command_with_settings() {
  mkdir -p config
  printf '[prod-db-*]\nbackground=#000030\n' > config/mysql.ini
  run zsh -f -c "$(peacock_env) source '$PLUGIN'; $(run_preexec 'mysql -h prod-db-01 -u app mydb')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 000030)"* ]]
  [[ "$output" == *"$(badge_seq prod-db-01)"* ]]
}

case_restores_after_the_command() {
  mkdir -p config
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  echo 'background=#003366' > .peacock
  run zsh -f -c "$(peacock_env) source '$PLUGIN'; $RUN_PRECMD; $(run_preexec 'ssh csw01'); printf SEP; $RUN_PRECMD"
  [ "$status" -eq 0 ]
  [[ "${output#*SEP}" == *"$(bg_seq 003366)"* ]]
}

case_expands_alias_before_matching() {
  mkdir -p config
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  run zsh -f -c "$(peacock_env) source '$PLUGIN'; $(run_preexec 'ssh -A csw01')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 300000)"* ]]
}

case_unquotes_words_before_matching() {
  mkdir -p config
  printf '[PROD]\nmatch-options = --port=13306\nbackground=#300000\n' > config/mysql.ini
  run zsh -f -c "$(peacock_env) source '$PLUGIN'; $(run_preexec 'mysql --port="13306"')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(bg_seq 300000)"* ]]
}

case_ignores_commands_without_settings() {
  mkdir -p config
  printf '[csw*]\nbackground=#300000\n' > config/ssh.ini
  local line
  for line in 'echo ssh csw01' 'ssh csw01 ls' 'sshfs csw01 /mnt' 'mysql -h csw01'; do
    run zsh -f -c "$(peacock_env) source '$PLUGIN'; $(run_preexec "$line")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

bats_test_function --description "precmd に _peacock_precmd を登録する" -- case_registers_precmd
bats_test_function --description "preexec に _peacock_preexec を登録する" -- case_registers_preexec
bats_test_function --description "PEACOCK_COMMANDS=0 なら preexec を登録しない" -- case_command_hook_can_be_disabled
bats_test_function --description "既存の precmd 関数を残す" -- case_keeps_existing_precmd
bats_test_function --description "CLI を PATH に追加する" -- case_adds_cli_to_path
bats_test_function --description "2回 source しても登録が重複しない" -- case_sourcing_twice_does_not_duplicate
bats_test_function --description "プロンプト表示時に .peacock の色を塗る" -- case_paints_on_prompt
bats_test_function --description "cd に合わせて塗り替え・リセットする" -- case_follows_cd_between_prompts
bats_test_function --description "相対パスとシンボリックリンク経由でも読み込める" -- case_works_via_relative_symlink
bats_test_function --description "関数内で source されても動く" -- case_works_when_sourced_in_function
bats_test_function --description "設定のあるコマンドでその配色にする" -- case_paints_on_hooked_command
bats_test_function --description "ssh 以外のコマンドも語の一致で判定する" -- case_paints_on_any_command_with_settings
bats_test_function --description "コマンドが終わると元の配色に戻る" -- case_restores_after_the_command
bats_test_function --description "エイリアスを展開した行で判定する" -- case_expands_alias_before_matching
bats_test_function --description "引用符を外した語で判定する" -- case_unquotes_words_before_matching
bats_test_function --description "設定のないコマンドでは何もしない" -- case_ignores_commands_without_settings
