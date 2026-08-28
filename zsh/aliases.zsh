
alias df='df -h'
alias c='clear'
alias cl='clear'
alias du1='du -hd1 2>/dev/null'
alias grep='grep --color=auto'

[[ $OSTYPE == darwin* || $OSTYPE == *bsd* ]] || alias top='top -d 1'

alias -- -='cd -'   # -- stops - being parsed as a flag

# :A resolves the symlink, :t takes the basename — Alpine and Termux point ip
# at busybox, which has no -c.
if (( $+commands[ip] )) && [[ ${commands[ip]:A:t} != busybox ]]; then
  alias ip='ip -c'
fi

(( $+commands[bridge] )) && alias bridge='bridge -c'

alias run-help=man   # zsh's own default; Debian's zsh-common overrides it

if (( ! $+commands[man] )); then
  man() {
    # rehash first: zsh caches the command hash, so a man installed since this
    # shell started is invisible to $commands until PATH is rescanned.
    rehash
    (( $+commands[man] )) && { unfunction man; command man "$@"; return }
    local hint
    if   (( $+commands[apk] ));     then hint='apk add mandoc man-pages'
    elif (( $+commands[apt-get] )); then hint='apt install man-db'
    elif (( $+commands[dnf] ));     then hint='dnf install man-db'
    elif (( $+commands[pacman] ));  then hint='pacman -S man-db man-pages'
    elif (( $+commands[pkg] ));     then hint='pkg install man'
    fi
    print -u2 "man: not installed${hint:+ — try: $hint}"
    return 127
  }
fi

case "$OSTYPE" in
  darwin*|*bsd*) _lsc='-G' ;;
  *)             _lsc='--color=auto' ;;
esac

case "$OSTYPE" in
  darwin*|*bsd*)
    _ls_notime=()
    _ls_noids=(-g -o)
    _ls_group=()
    ;;

  linux-musl*)
    _ls_notime=()
    _ls_noids=()
    _ls_group=()
    ;;

  *)
    _ls_notime=(--time-style=+)
    _ls_noids=(-g --no-group)
    _ls_group=(--group-directories-first)
    ;;
esac

# zsh expands aliases when a function definition is PARSED: a predefined ll
# (Fedora's colorls.sh) turns `ll() {` into `ls -l () {`. Must be top level.
unalias ll la 2>/dev/null

# Icons need a Nerd Font: NERD_FONT=0 in ~/.zshrc.local turns them off.
: "${NERD_FONT:=1}"
(( NERD_FONT )) && _icons=auto || _icons=never

# Owner/group drops on Termux at any width.
if [[ -n ${TERMUX_VERSION:-} || ${PREFIX:-} == *com.termux* ]]; then
  _ls_termux=1
else
  _ls_termux=0
fi

LS_NARROW_COLS=${LS_NARROW_COLS:-55}

# ll/la are functions for the width test at startup.
if (( $+commands[eza] )); then
  alias ls="eza --icons=$_icons"
  alias tree='eza --tree --icons=$_icons -I ".git|.DS_Store"'
  ll() {
    local -a f=(-l --git --icons="$_icons")
    local _columns=${COLUMNS:-$(stty size | awk '{print $2}')}
    local narrow=$(( _columns <= LS_NARROW_COLS ))
    # -g is what asks eza for the group; --no-user drops the other half.
    if (( _ls_termux || narrow )); then f+=(--no-user); else f+=(-g); fi
    (( _columns <= 50 )) && f+=(--no-time)
    eza "${f[@]}" --group-directories-first "$@"
  }
  compdef eza=ls   # reuse ls completions
else
  alias ls="command ls $_lsc"
  ll() {
    local -a f=(-l "$_lsc")
    local _columns=${COLUMNS:-$(stty size | awk '{print $2}')}
    local narrow=$(( _columns <= LS_NARROW_COLS ))
    (( _ls_termux || narrow )) && f+=("${_ls_noids[@]}")
    (( _columns <= 50 )) && f+=("${_ls_notime[@]}")
    command ls "${f[@]}" "${_ls_group[@]}" "$@"
  }
fi

la() { ll -A "$@"; }

alias l="command ls $_lsc"

# Debian renames these.
(( ! $+commands[bat] && $+commands[batcat] )) && alias bat=batcat
(( ! $+commands[fd]  && $+commands[fdfind] )) && alias fd=fdfind

# busybox diff (Alpine) has no --color.
[[ $OSTYPE == linux-musl* ]] || alias diff='diff --color=auto'

# =========================================================
# Git
# =========================================================

# Names follow the oh-my-zsh git plugin, but this is a hand-picked subset.

# ---------- Inspect ----------
alias gst='git status'
alias gss='git status --short --branch'
alias gd='PAGER="less -F -X" git diff'
alias gds='PAGER="less -F -X" git diff --staged'
alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'

# ---------- Stage & commit ----------
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'                                             # -v puts the diff in the editor
alias gcm='git commit -m'
alias gca='git commit -v --amend'
alias gcan='git commit -v --amend --no-edit'

# ---------- Branch & switch ----------
# switch/restore over checkout: `git checkout foo` silently discards changes
# when foo happens to be a path.
alias gb='git branch'
alias gsw='git switch'
alias gswc='git switch -c'
alias gco='git checkout'                                             # kept for detached HEAD / pathspecs
alias gcb='git checkout -b'

# ---------- Sync ----------
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias gp='git push'
alias gpf='git push --force-with-lease'                              # never --force: aborts if the remote moved

# ---------- Stash ----------
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'

# ---------- Rebase & merge ----------
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias gm='git merge'

# ---------- Undo ----------
alias grs='git restore'                                              # discard unstaged changes to a file
alias grss='git restore --staged'                                    # unstage, keep the changes
alias grh='git reset'
