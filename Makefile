# =============================================================================
#  Makefile — the same three commands on every platform
# =============================================================================
#
#   make install     install / update everything (idempotent)
#   make verify      headless self-check, exit code 1 on problems
#   make docs        regenerate KEYBINDINGS.md from the live keymaps
#   make format      format this config's Lua with stylua
#   make clean       remove plugin + tool installs (keeps your config)
#
#  Windows: `make` is not installed by default. Use install.ps1 instead; the
#  other targets are thin wrappers around nvim, and are documented in README.md.
# =============================================================================

SHELL := /bin/bash
NVIM  ?= nvim
CONFIG := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

.DEFAULT_GOAL := help

.PHONY: help install verify docs format lint clean update tools

help: ## Show this help
	@printf '\n\033[1mNeovim config\033[0m  %s\n\n' "$(CONFIG)"
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@printf '\n'

install: ## Install or update everything (idempotent)
	@bash "$(CONFIG)/install.sh"

verify: ## Headless self-check of the whole config
	@bash "$(CONFIG)/scripts/verify.sh"

docs: ## Regenerate KEYBINDINGS.md from the live registry
	@cd "$(CONFIG)" && $(NVIM) --headless -c "lua dofile('scripts/gen-docs.lua')" -c qa

format: ## Format this config's Lua with stylua
	@cd "$(CONFIG)" && stylua lua scripts

update: ## Update plugins and language tools
	@$(NVIM) --headless "+Lazy! sync" +qa
	@cd "$(CONFIG)" && $(NVIM) --headless -c "lua dofile('scripts/install-tools.lua')" -c qa
	@echo "Updated. Run 'make docs' if keymaps changed."

tools: ## Install or repair language servers, formatters, linters, debuggers
	@cd "$(CONFIG)" && $(NVIM) --headless -c "lua dofile('scripts/install-tools.lua')" -c qa

clean: ## Remove installed plugins and language tools (keeps the config)
	@printf 'Remove %s and %s? [y/<anything else>] ' \
		"$$(nvim --headless -c 'lua io.write(vim.fn.stdpath(\"data\"))' -c qa 2>/dev/null)" \
		"$$(nvim --headless -c 'lua io.write(vim.fn.stdpath(\"data\"))' -c qa 2>/dev/null)/mason"
	@read -r answer; [ "$$answer" = "y" ] || { echo "Cancelled."; exit 0; }
	rm -rf "$$(nvim --headless -c 'lua io.write(vim.fn.stdpath(\"data\"))' -c qa 2>/dev/null)/lazy"
	rm -rf "$$(nvim --headless -c 'lua io.write(vim.fn.stdpath(\"data\"))' -c qa 2>/dev/null)/mason"
	@echo "Cleaned. Next launch reinstalls everything."
