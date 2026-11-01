.PHONY: check link

# Apply the repo to $HOME via chezmoi (first run asks for the machine role)
link:
	./install.sh

# Best-effort validation of every config (run before committing)
check:
	@echo "== zsh =="
	@command -v zsh >/dev/null && { zsh -n home/dot_zshrc && echo "  zshrc syntax ok"; } || echo "  skipped (no zsh)"
	@echo "== nvim =="
	@if command -v luac >/dev/null; then luac -p home/dot_config/nvim/init.lua && echo "  init.lua syntax ok"; \
	 elif command -v nvim >/dev/null; then nvim --headless -u NORC --noplugin -c "luafile home/dot_config/nvim/init.lua" -c "qa" 2>&1 | tail -3; \
	 else echo "  skipped (no luac/nvim)"; fi
	@grep -n "vim\.loop\." home/dot_config/nvim/init.lua && echo "  WARN: deprecated vim.loop still present" || echo "  no deprecated vim.loop"
	@echo "== git =="
	@command -v chezmoi >/dev/null && { chezmoi --source "$$PWD" execute-template < home/dot_gitconfig.tmpl > /tmp/gitconfig.check && git config --file /tmp/gitconfig.check --list >/dev/null 2>&1 && echo "  gitconfig ok" || echo "  gitconfig FAIL"; } || echo "  skipped (no chezmoi)"
	@echo "== firefox =="
	@python3 -m json.tool firefox/policies.json >/dev/null 2>&1 && echo "  policies.json ok" || echo "  policies.json FAIL"
	@echo "== chezmoi =="
	@command -v chezmoi >/dev/null && { chezmoi --source "$$PWD" execute-template '{{ "ok" }}' >/dev/null && chezmoi --source "$$PWD" managed >/dev/null && echo "  chezmoi source ok"; } || echo "  skipped (no chezmoi)"
	@echo "== herdr =="
	@command -v herdr >/dev/null && { HERDR_CONFIG_PATH="$$PWD/home/dot_config/herdr/config.toml" herdr config check && echo "  herdr config ok"; } || echo "  skipped (no herdr)"
	@echo "== starship (toml) =="
	@command -v python3 >/dev/null && python3 -c "import tomllib,sys; tomllib.load(open('home/dot_config/starship/starship.toml','rb'))" 2>/dev/null && echo "  starship.toml ok" || echo "  skipped"
	@echo "done"
