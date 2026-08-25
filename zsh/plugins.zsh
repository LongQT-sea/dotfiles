# =========================================================
# Plugins
# =========================================================

ZPLUGINDIR="${ZSH_CONFIG_DIR:-$HOME/.config/zsh}/plugins"

_zplugin_load() {
  local plugin_path="${ZPLUGINDIR}/${2}"
  if [[ ! -d "$plugin_path" ]]; then
    mkdir -p "$ZPLUGINDIR"
    echo "Installing ${2}..."
    git clone --depth=1 --quiet "https://github.com/${1}/${2}" "$plugin_path" \
      || { echo "ERROR: failed to install ${2}" >&2; return 1; }
  fi
  source "${plugin_path}/${2}.plugin.zsh"
}

zplugin-update() {
  local dir
  for dir in "${ZPLUGINDIR}"/*/; do
    echo "Updating ${dir:t}..."
    git -C "$dir" pull --quiet --ff-only
  done
}

_zplugin_load zsh-users zsh-autosuggestions

# Must load LAST.
_zplugin_load zsh-users zsh-syntax-highlighting
_zplugin_load zsh-users zsh-history-substring-search
