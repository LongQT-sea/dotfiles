# My zsh dotfiles

A zsh setup I've spent far too much time on. No framework, just a few plugins, fzf/ripgrep bindings, Starship, and an installer that works across macOS, Linux, and Termux.

Plugins: [`zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions) [`zsh-syntax-highlighting`](https://github.com/zsh-users/zsh-syntax-highlighting) [`zsh-history-substring-search`](https://github.com/zsh-users/zsh-history-substring-search)

## Install
> [!Important]
> Requires true-color terminal.
> On macOS 15 and earlier, use Ghostty or iTerm2 or Tabby.

```zsh
git clone https://github.com/LongQT-sea/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

```zsh
./install.sh --dry-run   # print what would happen, change nothing
./install.sh --no-deps   # place files only, install nothing
./install.sh --link      # symlink to the repo instead of copying
```

> [!Note]
> **macOS** and **Termux** get JetBrainsMono Nerd Font automatic via [getnf](https://github.com/getnf/getnf) <br>
> On **macOS**, manually select the font in the Terminal.app profile's text settings.

---

## Using it

### Keys
> [!TIP]
> Press `Esc` to close any fuzzy picker (`Ctrl`–`R`, `Ctrl`–`T`, `Ctrl`–`G`, `Alt`–`C`, ...)

| Key | What it does |
|---|---|
| `Ctrl`–`R` | Fuzzy-search shell history. Type any fragment, `Enter` to run it. |
| `Ctrl`–`T` | Insert the selected file or directory path at the cursor. |
| `Ctrl`–`G` | Live-search file contents. `Enter` opens `$EDITOR` at the matching line. |
| `Alt`–`C`/`Esc`–`C` | `cd` into the selected directory. |
| `,,`–`Tab` | Type `,,` at the end of a word and press `Tab` for a fuzzy picker — files for `vim ,,`, directories for `cd ,,`, processes for `kill ,,`. |
| `Up` / `Down` | Filters history based on any substring currently on your command line. `git c`–`Up` only walks through your `git c…` commands. |
| `Right` / `End` | Accept the greyed-out suggestion. `Ctrl`–`Right` accepts one word at a time. |
| `Ctrl`–`\` | Toggle the auto suggestions on and off |
| `Esc`–`H` | Open the manpage for the command on the current line, syntax highlighted. |

### Inside a fuzzy picker

> [!IMPORTANT]
> On macOS, the **Option** ⌥ (Alt) key **requires** additional configuration to behave like it does on Windows or Linux.<br>
> **Terminal.app:** Settings → Profile → Keyboard → Use Option as Meta key.<br>
> **iTerm.app:** Settings → Profile → Keys → General → Left/Right Option key → change to **Esc+**.

| Key | What it does |
|---|---|
| `Alt`–`P` | Show or hide the preview pane. |
| `Alt`–`/` | In `Ctrl`–`T` and `Ctrl`–`G` only: Cycle the preview pane's size and position, then back to its original one. |
| `Alt`–`E` | In `Ctrl`–`T` only: Open the highlighted file in `$EDITOR` instead of inserting its path. |
| `Alt`–`.` | In `Ctrl`–`T` only: Toggle the visibility of dot files and directories. |

### Editing the line

| Key | What it does |
|---|---|
| `Ctrl`–`A` / `Ctrl`–`E` | Move to the start / end of the line, same as `Home` / `End`. |
| `Ctrl`–`Left` / `Ctrl`–`Right` | Move by word. `Alt`–`Left` / `Alt`–`Right` work too. |
| `Ctrl`–`W` | Delete the word before the cursor. |
| `Ctrl`–`K` | Delete from the cursor to the end of the line. |
| `Ctrl`–`U` | Delete from the cursor to the start of the line. |
| `Ctrl`–`Y` | Restore the text removed by the last `Ctrl`–`W`, `Ctrl`–`K`, or `Ctrl`–`U`. |

### Moving around

| Where | What it does |
|---|---|
| `z name` | Jump to a directory you've been in before — matches any part of the path. |
| `zi` | Same, but pick from a list. |
| `-` | Back to the previous directory. |
| `/some/dir` | A bare path on its own cds into it — no `cd` needed. |
| `l` `ll` `la` | Plain, long, long-with-dotfiles. `ll` drops columns on narrow terminals instead of wrapping. |
| `tree` | Recursive listing, `.git` and `.DS_Store` filtered out. |

### Git aliases

Short aliases follow oh-my-zsh naming — `gst` status, `gss` short status, `gd` diff, `gds` staged diff, `ga`/`gaa` add, `gc`/`gcm` commit, `gsw`/`gswc` switch, `gl`/`gp` pull/push, `gsta`/`gstp` stash, `gadog` for the graph log. The full list is `zsh/aliases.zsh`.

### Housekeeping

| Command | What it does |
|---|---|
| `compinit-refresh` | Pick up completions for a tool you just installed, instead of waiting for the daily rebuild. |
| `zplugin-update` | `git pull` every plugin. |
| ` command` | A leading space keeps a command out of your history. |

### Inside a pager

For anything that opens the pager like `git diff`, `git log`, `bat`, `less`, `man`, ...:

| Key | What it does |
|---|---|
| `Space`/`B` | Move down / up one screen. `Ctrl`–`F`/`Ctrl`–`B` do the same. |
| `d` / `u` | Move down / up half screen. |
| `g` / `G` | Jump to the top / bottom. |
| `/text`, `n`, `N` | Search, then next / previous match. |
| `q` | Quit. |

---

## Optional

### Git and SSH keys

```zsh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

cat > ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

# Add both keys: GitHub treats auth and signing separately, or commits show Unverified.
# Scopes live on the token, so this is once per machine — and worth dropping again after,
# since admin:public_key on a cached token lets someone add their own key.

gh auth login -s admin:public_key,admin:ssh_signing_key --skip-ssh-key
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(hostname) signing"

gh auth refresh -h github.com -r admin:public_key,admin:ssh_signing_key
ssh -T git@github.com
```

```zsh
# Change these
_NAME="Tieu Long"
_EMAIL="long025733@gmail.com"

git config --global user.name  "$_NAME"
git config --global user.email "$_EMAIL"
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global gpg.format ssh
git config --global commit.gpgsign true
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global url."git@github.com:".insteadOf https://github.com/

# Trust your own signatures locally, so `git log --show-signature` says "good".
# The address must match user.email above or no principal matches.
echo "$_EMAIL $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
```

### Node

```zsh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
exec zsh
nvm install --lts
```

---

## What lands where

| Repo file | Copied to | Notes |
|---|---|---|
| `zshrc` | `~/.zshrc` | Main file. Installers can append safely. |
| `zshenv` | `~/.zshenv` | PATH + EDITOR only. |
| `zsh/` | `~/.config/zsh/` | The `*.zsh` modules: `fzf` `aliases` `plugins` `bindings` `prompt`, sourced in that order. |
| `starship.toml` | `~/.config/starship.toml` | Starship's native default path. |
| `gitignore_global` | `~/.config/git/ignore` | Git's own XDG default — no `core.excludesFile` needed. |

Copies, so the repo can be moved or deleted afterwards. `--link` symlinks to it
instead. Switching either way is safe: anything displaced is moved to
`~/old_dotfiles/<timestamp>/`, mirroring its path — so a stale module the repo
no longer has stops being sourced, and `rm -rf ~/old_dotfiles` is the cleanup.

Never placed, never committed: the plugin clones under `~/.config/zsh/plugins/`,
and `~/.zshrc.local` for machine-local secrets.
