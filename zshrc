# ~/.zshrc — interactive shell configuration
#
# Lives at $HOME with ZDOTDIR unset. Modules live in $ZSH_CONFIG_DIR.

ZSH_CONFIG_DIR="$HOME/.config/zsh"

# =========================================================
# PATH
# =========================================================

# A login shell runs /etc/profile (Alpine, Debian) or path_helper (macOS)
# after .zshenv, dropping this. First, not last: the probes below need it.
typeset -U path PATH
path=("$HOME/.local/bin" $path)
export PATH

# Re-run .zshenv's editor pick now that PATH is complete.
for _ed in vim nvim vi; do
  (( $+commands[$_ed] )) && { export EDITOR=$_ed VISUAL=$_ed; break }
done
unset _ed

# =========================================================
# History
# =========================================================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY

# Write on entry, but do not import what other shells write: a new terminal
# gets everything so far, an open tab keeps its own history.
setopt INC_APPEND_HISTORY
unsetopt SHARE_HISTORY

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# =========================================================
# Shell behaviour
# =========================================================

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT  # sort file10 after file9, not after file1

# Off by default, so pasting a commented block runs `#` as a command — and any
# $(...) inside the "comment" executes for real.
setopt INTERACTIVE_COMMENTS


# =========================================================
# Pager
# =========================================================

# One word, not `sh -c '...'`: mandoc and busybox word-split MANPAGER instead
# of handing it to a shell, so quotes there are a syntax error.
_mp="$HOME/.local/bin/manpager"
if [[ -x $_mp ]] && (( $+commands[bat] || $+commands[batcat] )); then
  export MANPAGER="$_mp"
fi
unset _mp

# =========================================================
# Completion
# =========================================================

autoload -Uz compinit

# Full compinit once a day, -C otherwise (~11ms): -C never notices new tools.
# The staleness test must be an array assignment; [[ -n ... ]] does no globbing.
_zcompdump="$HOME/.zcompdump"
_zcd_stale=( ${_zcompdump}(N.mh+24) )   # N=null_glob  .=regular file  mh+24=older than 24h
if (( $#_zcd_stale )) || [[ ! -s $_zcompdump ]]; then
  compinit
  # Without this, an unchanged dump keeps its mtime and every start is slow.
  touch "$_zcompdump"
else
  compinit -C
fi
unset _zcompdump _zcd_stale

# After compinit, per zoxide's own docs: earlier and `z`/`zi` get no completions.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Force a rebuild now, rather than waiting for the daily run.
compinit-refresh() {
  rm -f "$HOME/.zcompdump"
  exec zsh
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # "doc" completes to "Documents"

# =========================================================
# Fuzzy finder
# =========================================================

# fzf >= 0.48 emits its own bindings; older versions ship them as files, in a
# different place on every distro.
if (( $+commands[fzf] )); then
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [[ -n $_fzf_init ]]; then
    eval "$_fzf_init"
  else
    for _d in \
      "${PREFIX:-/usr}/share/fzf" \
      /opt/homebrew/opt/fzf/shell \
      /usr/local/opt/fzf/shell \
      /usr/share/fzf \
      /usr/share/fzf/shell \
      /usr/share/doc/fzf/examples \
      /usr/local/share/examples/fzf/shell
    do
      [[ -r "$_d/key-bindings.zsh" ]] || continue
      source "$_d/key-bindings.zsh"
      [[ -r "$_d/completion.zsh" ]] && source "$_d/completion.zsh"
      break
    done
    unset _d
  fi
  unset _fzf_init
fi

# =========================================================
# Node / NVM
# =========================================================

export NVM_DIR="$HOME/.nvm"

# Defer nvm.sh (~11ms) to the first `nvm` call; PATH gets the newest version's
# bin directly. Completion stays eager, or `nvm <TAB>` is dead until first use.
_nvm_bins=("$NVM_DIR"/versions/node/*/bin(Nn))   # n = numeric sort, so v10 > v9
(( $#_nvm_bins )) && path=("${_nvm_bins[-1]}" $path)
unset _nvm_bins

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # --no-use: activating default spawns node, ~370ms.
  nvm() {
    unfunction nvm
    source "$NVM_DIR/nvm.sh" --no-use
    nvm "$@"
  }
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
fi

# =========================================================
# Modular Config Files
# =========================================================

# bindings AFTER plugins so its bindkeys win; prompt last. Guarded so a partial
# checkout still gives a usable shell.
for _f in fzf aliases plugins bindings prompt; do
  if [[ -r "$ZSH_CONFIG_DIR/$_f.zsh" ]]; then
    source "$ZSH_CONFIG_DIR/$_f.zsh"
  else
    print -u2 "warning: missing $ZSH_CONFIG_DIR/$_f.zsh"
  fi
done
unset _f

# Machine-local overrides
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local" || :

# =========================================================
# Installer-appended lines land below this point.
# =========================================================
