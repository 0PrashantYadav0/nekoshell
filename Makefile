# The developer entry points. Each target is one line of shell, so the same
# thing runs on a laptop, in a git hook and in CI.
.PHONY: help lint fmt test check hooks tools

help: ## list the targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-8s %s\n", $$1, $$2 }'

lint: ## shellcheck, shfmt, repository shape, actionlint, yamllint, markdownlint
	@scripts/lint.sh

fmt: ## rewrite every shell file with shfmt
	@scripts/lint.sh --fix

test: ## the whole bats suite
	@bats -r tests

check: lint test ## everything CI runs, in CI's order

hooks: ## install the git hooks in .githooks (pre-commit lint, commit-msg, pre-push tests)
	@git config core.hooksPath .githooks
	@chmod +x .githooks/*
	@echo "hooks installed: core.hooksPath = .githooks"

tools: ## install the linters and the test runner with Homebrew
	@brew install bats-core shellcheck shfmt actionlint yamllint markdownlint-cli2
