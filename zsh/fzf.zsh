# =========================================================
# fzf
# =========================================================

# Debian renames both binaries: fd -> fdfind, bat -> batcat.
if   (( $+commands[fd] ));     then _fd=fd
elif (( $+commands[fdfind] )); then _fd=fdfind
fi
if   (( $+commands[bat] ));    then _bat=bat
elif (( $+commands[batcat] )); then _bat=batcat
fi

if [[ -n $_fd ]]; then
  # --exclude .git: per fd's docs --hidden pulls in .git, which then swamps
  # every real result inside a repo.
  export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --exclude .git --strip-cwd-prefix"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
# No fd: leave both unset on purpose. fzf's own walker skips .git and
# node_modules; `find . -type f` skips nothing and buries real files.

# `vim ,,<Tab>` instead of the default `**`, which is Shift-8 twice.
export FZF_COMPLETION_TRIGGER=',,'

# UI
export FZF_DEFAULT_OPTS='
  --height=60%
  --layout=reverse
  --border=rounded
  --prompt="  "
  --pointer="  "
  --preview-window=right:65%:wrap:border-left
'

if [[ -n $_bat ]]; then
  _FZF_PREVIEW_CMD="$_bat --color=always --style=plain,numbers --line-range=:500 {}"
else
  _FZF_PREVIEW_CMD='head -n 500 {}'
fi
export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"

# Not exported: both are interpolated into --preview before fzf is spawned.
_FZF_BAT="$_bat"      # the rg preview needs the binary, not the command
unset _fd _bat

# Ctrl+F: file picker excluding hidden files
_fzf_file_no_hidden() {
  local result
  if [[ -n $FZF_DEFAULT_COMMAND ]]; then
    result=$(eval "${FZF_DEFAULT_COMMAND/--hidden /}" | fzf --preview "$_FZF_PREVIEW_CMD")
  elif fzf --walker=file --version >/dev/null 2>&1; then
    # fzf 0.43+. Dropping "hidden" stops it descending into dot-directories.
    result=$(fzf --walker=file,follow --preview "$_FZF_PREVIEW_CMD")
  else
    # Older fzf (Debian 12 ships 0.38): its default already prunes dot-paths.
    result=$(fzf --preview "$_FZF_PREVIEW_CMD")
  fi
  # (q-) quotes only when needed, so a path with spaces stays one word.
  [[ -n $result ]] && LBUFFER+="${(q-)result}"   # empty when cancelled with Esc
  zle reset-prompt
}
zle -N _fzf_file_no_hidden

# Ctrl+G: search file contents. --disabled lets rg do the matching, not fzf.
# Not in $( ): `become` execs $EDITOR in fzf's place and needs the terminal.
_fzf_rg_edit() {
  if (( ! $+commands[rg] )); then
    zle -M "rg is not installed"
    return 1
  fi
  local rg='rg --column --line-number --no-heading --color=always --smart-case '
  local prev='head -n 500 {1}'
  [[ -n $_FZF_BAT ]] && prev="$_FZF_BAT --color=always --style=plain,numbers --highlight-line {2} {1}"

  fzf --ansi --disabled \
      --bind "start:reload:$rg {q} || true" \
      --bind "change:reload:sleep 0.1; $rg {q} || true" \
      --delimiter : \
      --preview "$prev" \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
      --bind "enter:become(${EDITOR:-vi} {1} +{2})"
  zle reset-prompt
}
zle -N _fzf_rg_edit
