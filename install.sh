#!/bin/sh
# shellcheck disable=SC3043
# Set it all up: install whatever is missing, then put the files in place.
# Idempotent — safe to re-run.

set -eu

usage() {
  cat <<'EOF'
Set it all up: install whatever is missing, then put the files in place.
Idempotent — safe to re-run.

  ./install.sh            install missing tools, then copy files into place
  ./install.sh --link     symlink to the repo instead of copying
  ./install.sh --no-deps  place files only, install nothing
  ./install.sh --dry-run  print what would happen, change nothing

Displaced files are moved to ~/old_dotfiles/<timestamp>/ — delete that
directory to clean up.
EOF
}

REPO="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_ROOT="$HOME/old_dotfiles"
DRY=0
DEPS=1
MODE=copy

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --no-deps) DEPS=0 ;;
    --link)    MODE="link" ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# NO_COLOR is honoured; a pipe or a dumb TERM gets plain text.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  G=$(printf '\033[32m'); Y=$(printf '\033[33m'); R=$(printf '\033[0m')
else
  G=''; Y=''; R=''
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s%s%s\n' "$G" "$*" "$R"; }   # done / ready / act on this
warn() { printf '%s%s%s\n' "$Y" "$*" "$R"; }   # moved aside, skipped, failed
run()  { if [ "$DRY" -eq 1 ]; then say "  would: $*"; else "$@"; fi; }
# Same, minus chatter. Only stdout is dropped, so errors still reach you.
quiet() { if [ "$DRY" -eq 1 ]; then say "  would: $*"; else "$@" >/dev/null; fi; }

# sudo is requested per-command instead. Plain root with no SUDO_USER
# (a container, Termux) is fine and stays allowed.
if [ -n "${SUDO_USER:-}" ]; then
  cat >&2 <<EOF
Do not run this with sudo. It would leave root-owned files in $HOME, and
Homebrew refuses to install as root.

Run it as yourself:
  ./install.sh

It will ask for your password only when the package manager needs it.
EOF
  exit 1
fi

# ---------------------------------------------------------
# Platform
# ---------------------------------------------------------

# Alpine has busybox wget and no curl; macOS has curl and no wget.
fetch() {   # fetch URL OUTFILE
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    say "  no curl or wget available — cannot download $1" >&2
    return 1
  fi
}

ensure_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; return 0; fi
  done
  [ "$DEPS" -eq 1 ] || return 1

  say "Homebrew is missing — installing it first (this asks for your password)." >&2

  if ! run sudo -v; then
    say "sudo failed, so Homebrew cannot be installed. Install it yourself:" >&2
    say "  https://brew.sh" >&2
    return 1
  fi

  local script="${TMPDIR:-/tmp}/homebrew-install.sh"
  run fetch https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh "$script"
  run env NONINTERACTIVE=1 /bin/bash "$script"
  run rm -f "$script"
  [ "$DRY" -eq 1 ] && return 1

  # It is not on PATH in this shell yet.
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; return 0; fi
  done
  say "Homebrew install did not take; carrying on without it." >&2
  return 1
}

# Homebrew prints this step and never performs it. The `zsh` suffix matters:
# only it emits the fpath line brew's completions need.
ensure_brew_shellenv() {
  local b line f="$HOME/.zprofile"
  line=""
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && { line="eval \"\$($b shellenv zsh)\""; break; }
  done
  [ -n "$line" ] || return 0

  if [ -f "$f" ] && grep -qF "$line" "$f"; then
    ok "OK    ~/.zprofile  (brew shellenv)"
    return 0
  fi

  if [ "$DRY" -eq 1 ]; then
    say "  would: append brew shellenv to ~/.zprofile"
    return 0
  fi

  { echo ""; echo "$line"; } >> "$f"
  ok "WRITE ~/.zprofile  (brew shellenv)"
}

# macOS's system vimrc sets skip_defaults_vim, so stock vim loads none of
# defaults.vim. Written only when there is no ~/.vimrc at all.
ensure_vimrc() {
  local f="$HOME/.vimrc"

  if [ -e "$f" ] || [ -L "$f" ]; then
    ok "OK    ~/.vimrc"
    return 0
  fi

  if [ "$DRY" -eq 1 ]; then
    say "  would: create ~/.vimrc"
    return 0
  fi

  cat > "$f" <<'EOF'
unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

syntax on
filetype plugin indent on

let g:is_bash = 1
EOF
  ok "WRITE ~/.vimrc"
}

# A pager for man that bat can colour. It has to be one word in $MANPAGER:
# mandoc and busybox word-split it, so `sh -c '...'` is a syntax error there.
ensure_manpager() {
  local f="$HOME/.local/bin/manpager"
  local tmp="${TMPDIR:-/tmp}/manpager.$$"

  cat > "$tmp" <<'EOF'
#!/bin/sh
# Written by install.sh. man-db emits SGR colour, groff and mandoc emit
# backspace overstriking; bat wants neither, so one sed clears both.
ESC=$(printf '\033')
BS=$(printf '\b')

if command -v bat >/dev/null 2>&1; then
  hi() { bat -l man -p; }
elif command -v batcat >/dev/null 2>&1; then
  hi() { batcat -l man -p; }
else
  hi() { cat; }
fi

# man-db and macOS pipe the page in; mandoc passes it as a file and leaves
# stdin on the terminal, where reading it would hang.
if [ "$#" -gt 0 ]; then
  cat -- "$@"
else
  cat
fi | sed "s/$ESC\[[0-9;]*m//g; s/.$BS//g" | hi
EOF

  if [ -f "$f" ] && cmp -s "$tmp" "$f"; then
    rm -f "$tmp"
    ok "OK    ~/.local/bin/manpager"
    return 0
  fi

  if [ "$DRY" -eq 1 ]; then
    rm -f "$tmp"
    say "  would: write ~/.local/bin/manpager"
    return 0
  fi

  mkdir -p "$(dirname "$f")"
  mv "$tmp" "$f"
  chmod +x "$f"
  ok "WRITE ~/.local/bin/manpager"
}

# Termux first: Linux, but none of the usual managers and its own $PREFIX.
detect_pm() {
  case "${PREFIX:-}" in
    *com.termux*) local termux=1 ;;
    *)            local termux=0 ;;
  esac
  [ -n "${TERMUX_VERSION:-}" ] && termux=1
  if [ "$termux" -eq 1 ] && command -v pkg >/dev/null 2>&1; then
    echo pkg; return
  fi
  if [ "$(uname -s)" = Darwin ]; then
    if command -v brew >/dev/null 2>&1; then echo brew; else echo none; fi
    return
  fi
  for pm in apt-get dnf pacman zypper apk brew; do
    if command -v "$pm" >/dev/null 2>&1; then
      [ "$pm" = apt-get ] && pm=apt
      echo "$pm"; return
    fi
  done
  echo none
}

# Termux has no sudo. brew refuses to run as root, so it never gets one either.
SUDO=""
if [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo "; fi

pm_install_cmd() {
  case "$1" in
    brew)   echo "env HOMEBREW_NO_ASK=1 brew install" ;;
    pkg)    echo "pkg install -y" ;;
    apt)    echo "${SUDO}apt-get install -y" ;;
    dnf)    echo "${SUDO}dnf install -y" ;;
    pacman) echo "${SUDO}pacman -S --needed --noconfirm" ;;
    zypper) echo "${SUDO}zypper install -y" ;;
    apk)    echo "${SUDO}apk add" ;;
  esac
}

# Only these two: dnf and zypper refresh on demand, pacman -Sy without -u risks
# a partial upgrade.
# shellcheck disable=SC2086
pm_refresh() {
  case "$1" in
    apt) run ${SUDO}apt-get update ;;
    apk) run ${SUDO}apk update ;;
  esac
}

# Generic tool name -> package name for this manager.
pkg_name() {
  case "$1:$2" in
    apt:fd|dnf:fd) echo fd-find ;;      # binary installs as `fdfind`
    dnf:vim)       echo vim-enhanced ;;  # Fedora has no plain `vim` package
    *:rg)          echo ripgrep ;;
    *)             echo "$2" ;;
  esac
}

pkg_available() {
  case "$1" in
    apt)    apt-cache show "$2" >/dev/null 2>&1 ;;
    apk)    apk search -e "$2" 2>/dev/null | grep -q . ;;
    dnf)    dnf list "$2" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$2" >/dev/null 2>&1 ;;
    zypper) zypper --non-interactive search -x "$2" >/dev/null 2>&1 ;;
    *)      return 0 ;;   # assume yes
  esac
}

# Debian renames fd/bat. vim is skipped when nvim is already there, but not for
# a bare `vi`: busybox's applet is one, and it would mask vim on every Alpine.
have() {
  case "$1" in
    fd)  command -v fd  >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1 ;;
    bat) command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1 ;;
    vim) command -v vim >/dev/null 2>&1 || command -v nvim >/dev/null 2>&1 ;;
    *)   command -v "$1" >/dev/null 2>&1 ;;
  esac
}

install_starship() {
  local script="${TMPDIR:-/tmp}/starship-install.sh"

  [ "$DEPS" -eq 1 ] || return 0

  say "starship: installing the latest release from starship.rs"
  if ! run fetch https://starship.rs/install.sh "$script"; then
    warn "  starship: download failed — get it from https://starship.rs"
    return 0
  fi
  # Quiet: it ends with a wall of init snippets for every shell, and a $PATH
  # warning that .zshenv already answers. Non-fatal: prompt.zsh has a fallback.
  quiet sh "$script" -y -b "$HOME/.local/bin" || warn "  starship: installer failed"
  run rm -f "$script"
  return 0
}

NERD_FONT="JetBrainsMono"
NERD_FONT_OK=0

# Terminal.app and Termux ship unpatched fonts; the prompt and eza need one.
# getnf covers both, and on Termux also fills ~/.termux/font.ttf, its one slot.
install_nerd_font() {
  local bin script f
  local found=0

  if [ "$PM" = pkg ]; then
    # The family on disk is just a cache; the slot is what the terminal reads.
    [ -f "$HOME/.termux/font.ttf" ] && found=1
  else
    # Two layouts: getnf makes a subdirectory, Homebrew's cask drops flat .ttf.
    # getnf sees only its own, so without this it installs a duplicate family.
    [ -d "$HOME/Library/Fonts/$NERD_FONT" ] && found=1
    for f in "$HOME/Library/Fonts/$NERD_FONT"*NerdFont*; do
      [ -e "$f" ] && found=1
    done
  fi
  if [ "$found" -eq 1 ]; then
    ok "font:     $NERD_FONT Nerd Font already installed"
    NERD_FONT_OK=1
    return 0
  fi

  [ "$DEPS" -eq 1 ] || return 0

  # ~/.local/bin is not on PATH yet on macOS, so probe it directly too.
  if ! command -v getnf >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/getnf" ]; then
    ok "font:     installing getnf"
    script="${TMPDIR:-/tmp}/getnf-install.sh"
    run fetch https://raw.githubusercontent.com/LongQT-sea/getnf/main/install.sh "$script"
    # cd first: the installer curls getnf.tmp into the current directory.
    ( cd "${TMPDIR:-/tmp}" && run bash "$script" --silent )
    run rm -f "$script"
  fi

  bin="$HOME/.local/bin/getnf"
  command -v getnf >/dev/null 2>&1 && bin="$(command -v getnf)"

  ok "font:     installing $NERD_FONT Nerd Font"
  if run "$bin" -i "$NERD_FONT"; then
    NERD_FONT_OK=1
  else
    warn "font:     failed — grab it by hand from https://nerdfonts.com"
  fi
  return 0
}

install_deps() {
  local pm="$1"
  local tool p cmd tools
  local missing="" pkgs="" manual=""

  tools="curl git zsh eza bat fd fzf rg zoxide vim"
  [ "$pm" = pkg ] && tools="starship $tools"

  for tool in $tools; do
    have "$tool" || missing="$missing $tool"
  done
  missing="${missing# }"

  if [ -z "$missing" ]; then
    ok "deps: all present"
    return
  fi
  say "deps: missing — $missing"

  if [ "$DEPS" -eq 0 ]; then
    say "  --no-deps given, skipping"
    return
  fi
  if [ "$pm" = none ]; then
    say "  no package manager found" >&2
    for tool in $missing; do
      case "$tool" in
        curl) ;;
        *)    say "  $tool: install by hand" >&2 ;;
      esac
    done
    return
  fi

  # Before the probe, not after: apk searches an empty cache and calls every
  # package missing. Stale apt lists 404 on the versioned .deb.
  pm_refresh "$pm"

  for tool in $missing; do
    p="$(pkg_name "$pm" "$tool")"
    if pkg_available "$pm" "$p"; then pkgs="$pkgs $p"; else manual="$manual $tool"; fi
  done

  cmd="$(pm_install_cmd "$pm")"
  if [ -n "$pkgs" ] && [ -n "$cmd" ]; then
    # Unquoted on purpose: has to split into command + one word per package.
    # shellcheck disable=SC2086
    run $cmd$pkgs
  fi

  for tool in $manual; do
    say "  $tool: no $pm package — install by hand" >&2
  done
}

# ---------------------------------------------------------
# Login shell
# ---------------------------------------------------------

login_zsh() {
  if [ "$(uname -s)" = Darwin ] && [ -x /bin/zsh ]; then
    echo /bin/zsh
  else
    command -v zsh
  fi
}

# The recorded login shell. $SHELL is only a fallback — it is inherited, and
# unset in containers, which would re-run chsh every time.
current_shell() {
  local u
  u="$(id -un)"
  if [ "$(uname -s)" = Darwin ]; then
    dscl . -read "/Users/$u" UserShell 2>/dev/null | awk '{print $2}'
  elif command -v getent >/dev/null 2>&1; then
    getent passwd "$u" 2>/dev/null | cut -d: -f7
  fi
}

ensure_login_shell() {
  local target current
  have zsh || return 0
  target="$(login_zsh)"

  # Alpine's busybox has no chsh; it lives in the shadow package.
  if ! command -v chsh >/dev/null 2>&1; then
    warn "shell:    no chsh here — point your login shell at $target by hand"
    return 0
  fi
  current="$(current_shell)"
  [ -n "$current" ] || current="${SHELL:-}"

  if [ "$current" = "$target" ]; then
    ok "shell:    already $target"
    return 0
  fi

  # Never point a login shell at something that will not start.
  if ! "$target" -c 'exit 0' 2>/dev/null; then
    warn "shell:    $target does not run — leaving your login shell alone"
    return 0
  fi

  # Termux ships its own chsh: no /etc/shells, no sudo, takes a bare name.
  if [ "$PM" = pkg ]; then
    run chsh -s zsh
    ok "shell:    login shell set to zsh"
    return 0
  fi

  # chsh refuses any shell not listed in /etc/shells.
  if [ -r /etc/shells ] && ! grep -qxF "$target" /etc/shells; then
    if [ -n "$SUDO" ] || [ "$(id -u)" = 0 ]; then
      if [ "$DRY" -eq 1 ]; then
        say "  would: append $target to /etc/shells"
      else
        # Unquoted $SUDO on purpose: empty, or the word "sudo".
        # shellcheck disable=SC2086
        printf '%s\n' "$target" | ${SUDO}tee -a /etc/shells >/dev/null
      fi
    else
      warn "shell:    $target is not in /etc/shells — run: chsh -s $target"
      return 0
    fi
  fi

  # chsh asks for your password, so it needs a terminal to ask on.
  if [ ! -t 0 ]; then
    warn "shell:    no terminal to prompt on — run: chsh -s $target"
    return 0
  fi

  say "shell:    switching login shell to $target (asks for your password)"
  if run chsh -s "$target"; then
    ok "shell:    login shell is now $target — takes effect at next login"
  else
    warn "shell:    chsh failed — run it yourself: chsh -s $target"
  fi
}

# zshrc rebuilds ~/.zcompdump only once a day. Dropping it forces a rescan at
# the next start — `exec zsh -l` below, a login shell, so fpath is complete.
clear_compdump() {
  local f
  for f in "$HOME"/.zcompdump*; do
    [ -e "$f" ] || continue
    run rm -f "$f"
  done
}

# ---------------------------------------------------------
# Placing files
# ---------------------------------------------------------

# Copying is the default: the files in $HOME are real, so the repo can be moved
# or deleted afterwards. --link symlinks instead, for working on the repo live.

# A filter rewrites a repo file during the copy, not after, or the next run
# reads it as local drift. Termux is phone-width: seven components do not fit.
termux_directory_tweak() {
  sed -e '/^\[directory\]/,/^\[/ s/^truncate_to_repo = false/truncate_to_repo = true/' \
      -e '/^\[directory\]/,/^\[/ s/^truncation_length = 7/truncation_length = 4/' "$1"
}

stash() {   # stash PATH REL
  local path="$1" rel="$2"
  local dest="$BACKUP_ROOT/$STAMP/$rel"

  warn "SAVE  ~/$rel -> old_dotfiles/$STAMP/$rel"
  run mkdir -p "$(dirname "$dest")"
  run mv "$path" "$dest"
}

# copy_file SRC DST REL FRESH [FILTER] — FRESH=1: just cleared, so there is
# nothing left to compare against or back up.
copy_file() {
  local src="$1" dst="$2" rel="$3" fresh="$4" filter="${5:-}"
  local tmp=""

  if [ -n "$filter" ]; then
    tmp="${TMPDIR:-/tmp}/dotfiles-$$-${rel##*/}"
    "$filter" "$src" > "$tmp"
    src="$tmp"
  fi

  # -L first: cmp follows a symlink, so a link into the repo compares equal
  # to the file it points at.
  if [ "$fresh" -eq 0 ] && [ ! -L "$dst" ] && [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    ok "OK    ~/$rel"
  else
    if [ "$fresh" -eq 0 ] && { [ -e "$dst" ] || [ -L "$dst" ]; }; then
      stash "$dst" "$rel"
    fi
    ok "COPY  ~/$rel"
    run mkdir -p "$(dirname "$dst")"
    run cp "$src" "$dst"
  fi

  [ -z "$tmp" ] || rm -f "$tmp"
}

prune_dir() {
  local src="$1" dst="$2" rel="$3"
  local f name

  if [ -L "$dst" ] || [ ! -d "$dst" ]; then return 0; fi

  for f in "$dst"/*; do
    if [ ! -f "$f" ] || [ -L "$f" ]; then continue; fi
    name="${f##*/}"
    [ -e "$src/$name" ] && continue
    stash "$f" "$rel/$name"
  done
}

# Top-level regular files only: once live, this directory also holds the plugin
# clones and zsh's own state, which nothing here should touch.
copy_dir() {
  local src="$1" dst="$2" rel="$3" fresh="$4"
  local f

  run mkdir -p "$dst"
  for f in "$src"/*; do
    [ -f "$f" ] || continue
    copy_file "$f" "$dst/${f##*/}" "$rel/${f##*/}" "$fresh"
  done
  prune_dir "$src" "$dst" "$rel"
}

place_link() {
  local src="$1" dst="$2" rel="$3" name="$4"
  local disp="~/$rel"
  [ -d "$src" ] && disp="$disp/"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "OK    $disp"
    return
  fi

  # One of ours (e.g. the other starship variant): replace, do not back up.
  if [ -L "$dst" ]; then
    case "$(readlink "$dst")" in
      "$REPO"/*)
        ok "RELINK $disp -> $name"
        run rm "$dst"
        run ln -s "$src" "$dst"
        return
        ;;
    esac
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    stash "$dst" "$rel"
  fi

  ok "LINK  $disp -> $name"
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
}

place() {   # place REPO_PATH HOME_PATH [FILTER]
  local name="$1" rel="$2" filter="${3:-}"
  local src="$REPO/$name" dst="$HOME/$rel"
  local fresh=0

  if [ ! -e "$src" ]; then
    warn "SKIP  ~/$rel  (missing in repo: $name)"
    return
  fi

  local disp="~/$rel"
  [ -d "$src" ] && disp="$disp/"

  if [ "$MODE" = link ]; then
    # $HOME holds the repo file here, so a filter has nowhere to write.
    [ -z "$filter" ] || warn "NOTE  $disp  (--link shares the repo file; $filter not applied)"
    place_link "$src" "$dst" "$rel" "$name"
    return
  fi

  # From an earlier --link run: it points into the repo, so nothing of yours
  # is lost by dropping it.
  if [ -L "$dst" ]; then
    case "$(readlink "$dst")" in
      "$REPO"/*)
        warn "UNLINK $disp  (was a symlink into the repo)"
        run rm "$dst"
        fresh=1
        ;;
    esac
  fi

  if [ -d "$src" ]; then
    copy_dir "$src" "$dst" "$rel" "$fresh"
  else
    copy_file "$src" "$dst" "$rel" "$fresh" "$filter"
  fi
}

# Not inside detect_pm: ensure_brew evals `brew shellenv`, which the $( )
# subshell would discard.
if [ "$(uname -s)" = Darwin ]; then
  ensure_brew || true
fi
PM="$(detect_pm)"

say "repo:     $REPO"
say "platform: $(uname -s) $(uname -m), package manager: $PM"
say "mode:     $MODE"
[ "$DRY" -eq 1 ] && warn "(dry run — nothing will change)"
say ""

# Before install_deps (starship lands in ~/.local/bin). zsh creates neither,
# and a missing parent for HISTFILE silently discards history.
run mkdir -p "$HOME/.local/bin" "$HOME/.config"

install_deps "$PM"

[ "$PM" = pkg ] || install_starship
say ""

if [ "$(uname -s)" = Darwin ] || [ "$PM" = pkg ]; then
  install_nerd_font
  say ""
fi

# Only Termux wants the prompt's directory segment shortened.
FILTER=""
[ "$PM" = pkg ] && FILTER=termux_directory_tweak

place zshenv            .zshenv
place zshrc             .zshrc
place zsh               .config/zsh
place starship.toml     .config/starship.toml  "$FILTER"
place gitignore_global  .config/git/ignore

if [ "$(uname -s)" = Darwin ]; then
  ensure_brew_shellenv
  ensure_vimrc
fi

ensure_manpager

say ""
ensure_login_shell
clear_compdump

say ""

if [ "$NERD_FONT_OK" -eq 1 ]; then
  if [ "$PM" = pkg ]; then
    ok "Nerd Font ready — Termux is using it now."
  else
    ok "Nerd Font ready. Open your Terminal font settings and choose"
    ok "\"JetBrainsMono Nerd Font\", then open a new terminal window."
  fi
  say ""
fi

# Nests rather than replaces (a child cannot exec over its parent), so ^D
# returns you where you started. Skipped without a TTY.
if [ "$DRY" -eq 0 ] && [ -t 0 ] && [ -t 1 ] && have zsh; then
  ok "starting zsh — plugins auto install on this first run."
  say ""
  exec zsh -l
fi

ok "done — run 'exec zsh' (plugins self-install on first start)"
