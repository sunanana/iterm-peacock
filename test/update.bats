#!/usr/bin/env bats
# update サブコマンドのテスト。
# 実際の配布と同じ形（リモート → git clone したインストール先）を一時ディレクトリに作り、
# インストール先の CLI から update を実行する。
# 日本語のテスト名を使うため、@test ではなく関数を bats_test_function で登録している。

load test_helper

setup() {
  cd "$BATS_TEST_TMPDIR"
  # 開発者の git 設定（署名・フックなど）を持ち込まない
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

  # src は新しい版を出す側、remote.git は配布元、install は利用者が clone したもの
  mkdir src
  cp -R "$REPO/bin" "$REPO/iterm-peacock.sh" src/
  git -C src init -q -b main
  git -C src add .
  git -C src commit -qm v1
  git clone -q --bare src remote.git
  git -C src remote add origin "$PWD/remote.git"
  git clone -q remote.git install
}

# 配布元に新しいコミットを出す
publish() {
  echo "$1" >> src/CHANGES
  git -C src add CHANGES
  git -C src commit -qm "$1"
  git -C src push -q origin main
}

head_of() {
  git -C "$1" rev-parse HEAD
}

case_updates_to_latest() {
  local before
  before="$(git -C install rev-parse --short HEAD)"
  publish v2
  run install/bin/iterm-peacock update
  [ "$status" -eq 0 ]
  [ "$(head_of install)" = "$(head_of src)" ]
  [[ "$output" == *"updated $before -> $(git -C src rev-parse --short HEAD)"* ]]
  [[ "$output" == *'open a new shell'* ]]
}

case_already_up_to_date() {
  run install/bin/iterm-peacock update
  [ "$status" -eq 0 ]
  [[ "$output" == *'already up to date'* ]]
}

case_works_through_symlink() {
  publish v2
  ln -s "$PWD/install/bin/iterm-peacock" link
  run ./link update
  [ "$status" -eq 0 ]
  [ "$(head_of install)" = "$(head_of src)" ]
}

case_ignores_untracked_files() {
  touch install/notes.txt
  publish v2
  run install/bin/iterm-peacock update
  [ "$status" -eq 0 ]
  [ "$(head_of install)" = "$(head_of src)" ]
}

case_refuses_local_changes() {
  local before
  echo '# local' >> install/iterm-peacock.sh
  before="$(head_of install)"
  publish v2
  run install/bin/iterm-peacock update
  [ "$status" -eq 1 ]
  [[ "$output" == *'has local changes'* ]]
  [ "$(head_of install)" = "$before" ]
}

case_refuses_other_branch() {
  local before
  git -C install switch -q -c feature
  before="$(head_of install)"
  publish v2
  run install/bin/iterm-peacock update
  [ "$status" -eq 1 ]
  [[ "$output" == *"on 'feature', not 'main'"* ]]
  [ "$(head_of install)" = "$before" ]
}

case_refuses_diverged_history() {
  local before
  echo local >> install/LOCAL
  git -C install add LOCAL
  git -C install commit -qm local
  before="$(head_of install)"
  publish v2
  run install/bin/iterm-peacock update
  [ "$status" -eq 1 ]
  [[ "$output" == *'could not fast-forward'* ]]
  [ "$(head_of install)" = "$before" ]
}

case_refuses_without_upstream() {
  git -C install branch -q --unset-upstream
  run install/bin/iterm-peacock update
  [ "$status" -eq 1 ]
  [[ "$output" == *'has no upstream'* ]]
}

case_refuses_non_clone() {
  mkdir plain
  cp -R src/bin src/iterm-peacock.sh plain/
  run plain/bin/iterm-peacock update
  [ "$status" -eq 1 ]
  [[ "$output" == *'is not a git clone'* ]]
}

case_does_not_update_parent_repository() {
  local before
  mkdir -p dotfiles/tool
  cp -R src/bin src/iterm-peacock.sh dotfiles/tool/
  git -C dotfiles init -q -b main
  git -C dotfiles add .
  git -C dotfiles commit -qm dotfiles
  before="$(head_of dotfiles)"
  run dotfiles/tool/bin/iterm-peacock update
  [ "$status" -eq 1 ]
  [[ "$output" == *'is not a git clone'* ]]
  [ "$(head_of dotfiles)" = "$before" ]
}

case_rejects_extra_arguments() {
  run install/bin/iterm-peacock update now
  [ "$status" -eq 1 ]
  [[ "$output" == *'usage: iterm-peacock update'* ]]
}

bats_test_function --description "配布元の最新版まで進める" -- case_updates_to_latest
bats_test_function --description "最新なら何も変えずにそう表示する" -- case_already_up_to_date
bats_test_function --description "シンボリックリンク経由でもインストール先を更新する" -- case_works_through_symlink
bats_test_function --description "追跡していないファイルがあっても更新する" -- case_ignores_untracked_files
bats_test_function --description "手元の変更があれば更新しない" -- case_refuses_local_changes
bats_test_function --description "既定ブランチ以外にいれば更新しない" -- case_refuses_other_branch
bats_test_function --description "配布元にないコミットがあれば更新しない" -- case_refuses_diverged_history
bats_test_function --description "上流ブランチがなければ更新しない" -- case_refuses_without_upstream
bats_test_function --description "git clone でなければ更新しない" -- case_refuses_non_clone
bats_test_function --description "親ディレクトリの別リポジトリを更新しない" -- case_does_not_update_parent_repository
bats_test_function --description "余分な引数を拒否する" -- case_rejects_extra_arguments
