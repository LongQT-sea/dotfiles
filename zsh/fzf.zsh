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
  # Referenced at call time by _fzf_compgen_*; must stay set.
  _FZF_FD_OPTS=(--hidden --exclude .git --exclude .zsh_sessions --exclude '.zcompdump*')

  export FZF_DEFAULT_COMMAND="$_fd ${(j: :)${(q)_FZF_FD_OPTS[@]}} --strip-cwd-prefix"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

  # Tab completion doesn't read FZF_DEFAULT_COMMAND; it calls these if defined.
  _FZF_FD="$_fd"
  _fzf_compgen_path() { $_FZF_FD "${_FZF_FD_OPTS[@]}" . "$1" }
  _fzf_compgen_dir()  { $_FZF_FD --type d "${_FZF_FD_OPTS[@]}" . "$1" }
fi
# No fd: leave the command unset on purpose. fzf's own walker skips .git and
# node_modules; `find . -type f` skips nothing and buries real results.

# `vim ,,<Tab>` instead of the default `**`.
export FZF_COMPLETION_TRIGGER=',,'

export FZF_DEFAULT_OPTS='
  --height=99%
  --layout=reverse
  --border=rounded
  --prompt="  "
  --pointer="  "
  --preview-window=right:50%:wrap:border-left
  --bind=alt-p:toggle-preview
  --bind="alt-/:change-preview-window(75%|down,border-top|)"
'

if (( $+commands[eza] )); then
  _lsdir="eza -lA --icons=auto --group-directories-first --color=always"
else
  case "$OSTYPE" in
    darwin*|*bsd*) _lsdir='ls -lA -G' ;;
    *)             _lsdir='ls -lA --color=always' ;;
  esac
fi

if [[ -n $_bat ]]; then
  _FZF_PREVIEW_CMD="if [ -d {} ]; then $_lsdir {}; else $_bat --color=always --style=plain,numbers --line-range=:500 {}; fi"
else
  _FZF_PREVIEW_CMD="if [ -d {} ]; then $_lsdir {}; else head -n 500 {}; fi"
fi

export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD' --bind='alt-e:execute(\${EDITOR:-vi} {})+abort'"

# Alt-. toggles hidden files. Guarded: with no fd both reloads are empty and
# wipe the list. State lives in --header-label, which fzf only paints on a
# header border — there is no --header here. `case` not `[[`: transform runs
# under sh, where [[ is not a builtin.
if [[ -n $FZF_DEFAULT_COMMAND ]]; then
  _FZF_FD_NOHIDDEN="${FZF_DEFAULT_COMMAND/--hidden /}"

  FZF_CTRL_T_OPTS+="
--bind 'alt-.:transform:
case \$FZF_HEADER_LABEL in
  nohidden) echo \"change-header-label()+reload($FZF_DEFAULT_COMMAND)\" ;;
  *)        echo \"change-header-label(nohidden)+reload($_FZF_FD_NOHIDDEN)\" ;;
esac'"
fi

_FZF_BAT="$_bat"
unset _fd _bat _lsdir

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
      --preview-window "right:40%:wrap:border-left:+{2}+3/3" \
      --bind "enter:become(${EDITOR:-vi} {1} +{2})"
  zle reset-prompt
}
zle -N _fzf_rg_edit
