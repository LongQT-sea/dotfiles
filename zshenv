# ~/.zshenv — read by EVERY zsh invocation. Keep it tiny; interactive things
# belong in .zshrc. It exists for PATH: `zsh -c` reads only this file.

# ---------- Editor ----------
for _ed in vim nvim vi; do
  if (( $+commands[$_ed] )); then
    export EDITOR=$_ed VISUAL=$_ed
    break
  fi
done
unset _ed

# ---------- PATH ----------
# macOS path_helper runs after this and demotes ~/.local/bin, so .zshrc
# re-prepends. Both needed: here for scripts, there for interactive shells.
typeset -U path PATH
path=("$HOME/.local/bin" $path)
export PATH

# ---------- GPG ----------
# Guarded: $(tty) prints "not a tty" in scripts, and this file runs for those too.
if [[ -t 0 ]]; then
    export GPG_TTY=$(tty)
fi
