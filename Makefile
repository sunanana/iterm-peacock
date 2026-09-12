.DEFAULT_GOAL := help

help: ## ヘルプメッセージ表示
	@echo "Makefile Commands"
	@echo ""
	@# Primary commands (no slash)
	@primary_commands=$$(grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v '/'); \
	if [ -n "$$primary_commands" ]; then \
		echo "$$primary_commands" | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'; \
		echo ""; \
	fi
	@# Hierarchical commands (with slash) - group by prefix
	@grep -E '^[a-zA-Z_-]+/[a-zA-Z_/-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	sort | \
	awk 'BEGIN {FS = ":.*?## "; current_group = ""} \
	{ \
		split($$1, parts, "/"); \
		group = parts[1]; \
		if (group != current_group) { \
			if (current_group != "") print ""; \
			printf "\033[32m%s:\033[0m\n", group; \
			current_group = group; \
		} \
		printf "  %-20s %s\n", $$1, $$2; \
	}'

.PHONY: help setup test test/hook test/keys test/command test/cli test/picker test/plugin

setup: ## 開発に必要なものを入れる（テストに使う bats）
	brew install bats-core

test: ## 全テスト実行（先に make setup）
	bats test/

test/hook: ## シェルフックのテストだけ実行（bash と zsh）
	bats test/hook.bats

test/keys: ## キーごとのエスケープシーケンスのテストだけ実行（bash と zsh）
	bats test/keys.bats

test/command: ## コマンド連動のテストだけ実行（bash と zsh）
	bats test/command.bats

test/cli: ## CLI のテストだけ実行
	bats test/cli.bats

test/picker: ## 配色ピッカーのテストだけ実行（疑似端末を使うため数十秒かかる）
	bats test/picker.bats

test/plugin: ## zsh プラグインのテストだけ実行
	bats test/plugin.bats
