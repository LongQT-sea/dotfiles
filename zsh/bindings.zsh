# =========================================================
# Keybindings
# =========================================================

# Load-bearing: with no explicit -e/-v, zsh takes the keymap from $EDITOR,
# which matches *vi*. Use `bindkey -v` for vi editing.
bindkey -e

# The cursor is hard to spot inside highlighted pasted text.
zle_highlight=(paste:none)

# Sourced after plugins.zsh so these win.

bindkey '^U' backward-kill-line       # bash-like Ctrl+U

bindkey '^[[1;5C' forward-word        # Ctrl+Right
bindkey '^[[1;5D' backward-word       # Ctrl+Left
bindkey '^[[H'  beginning-of-line     # Home      # xterm, most modern terminals
bindkey '^[[F'  end-of-line           # End
bindkey '^[OH'  beginning-of-line     # Home      # application cursor mode
bindkey '^[OF'  end-of-line           # End
bindkey '^[[1~' beginning-of-line     # Home      # linux console, tmux, PuTTY
bindkey '^[[4~' end-of-line           # End
bindkey '^[[7~' beginning-of-line     # Home      # rxvt
bindkey '^[[8~' end-of-line           # End
bindkey '^F' _fzf_file_no_hidden      # Ctrl+F    # file picker, defined in fzf.zsh
bindkey '^G' _fzf_rg_edit             # Ctrl+G    # grep contents, also fzf.zsh

# fzf binds Tab in whatever keymap is current when it loads — viins, since
# $EDITOR is vim — and the `bindkey -e` above then moves us to emacs.
(( $+widgets[fzf-completion] )) && bindkey '^I' fzf-completion
bindkey '^\' autosuggest-toggle       # Ctrl+\    # toggle autosuggestions

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
