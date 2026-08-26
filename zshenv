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

# ---------- Locale ----------
# Containers and `pct enter` hand over no locale, leaving LC_CTYPE at POSIX:
# zsh counts the 3 bytes of a glyph like ❯ as 3 columns and redraws the line in
# the wrong place. Anything other than C/POSIX was chosen deliberately, so leave it.
_ctype=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
if [[ -z $_ctype || $_ctype == (C|POSIX) ]]; then
  # No `locale` (busybox, musl): C.UTF-8 is the built-in default there.
  if (( $+commands[locale] )); then
    _locales=(${(f)"$(locale -a 2>/dev/null)"})
  else
    _locales=()
  fi
  for _l in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    if (( $#_locales == 0 )) || (( ${_locales[(I)$_l]} )); then
      # Both outrank LANG, so a C left in either would swallow the export below.
      [[ ${LC_ALL:-}   == (C|POSIX) ]] && unset LC_ALL
      [[ ${LC_CTYPE:-} == (C|POSIX) ]] && unset LC_CTYPE
      [[ -z ${LANG:-} || $LANG == (C|POSIX) ]] && export LANG=$_l
      break
    fi
  done
  unset _locales _l
fi
unset _ctype

# ---------- TERM ----------
# `docker exec` and `pct enter` hand over a bare TERM=xterm, whose terminfo
# declares 8 colours, so zsh drops every colour above index 7. Naming a
# 256-colour entry that isn't installed breaks more than it fixes.
if [[ $TERM == xterm ]]; then
  for _ti in "$HOME/.terminfo" /etc/terminfo /lib/terminfo /usr/share/terminfo; do
    # 'x' on Linux, hex '78' on macOS and the BSDs.
    if [[ -e $_ti/x/xterm-256color || -e $_ti/78/xterm-256color ]]; then
      export TERM=xterm-256color
      break
    fi
  done
  unset _ti
fi

# ---------- GPG ----------
# Guarded: $(tty) prints "not a tty" in scripts, and this file runs for those too.
if [[ -t 0 ]]; then
    export GPG_TTY=$(tty)
fi
