# =========================================================
# Prompt
# =========================================================

export VIRTUAL_ENV_DISABLE_PROMPT=1   # keep venv out of the prompt

FUNCNEST=100

if (( $+commands[starship] )); then
  export STARSHIP_LOG=error
  eval "$(starship init zsh)"

  autoload -Uz add-zsh-hook add-zle-hook-widget

  TRANSIENT_PROMPT="${PROMPT// prompt / prompt --profile transient }"

  # Skip if starship's init string changed shape and the rewrite missed it,
  # so we never re-render the whole bar on every accepted line.
  if [[ $TRANSIENT_PROMPT != "$PROMPT" ]]; then
    function transient-prompt-precmd {
      TRAPINT() { transient-prompt; return $(( 128 + $1 )) }
      SAVED_PROMPT="$(eval "printf '%s' \"${TRANSIENT_PROMPT}\"")"
    }
    add-zsh-hook precmd transient-prompt-precmd

    function transient-prompt {
      # A job killed by SIGINT re-enters TRAPINT with ZLE inactive.
      zle || return 0
      PROMPT="$SAVED_PROMPT" RPROMPT='' zle .reset-prompt
    }
    add-zle-hook-widget zle-line-finish transient-prompt
  fi
else
  # Fallback so a box without starship still gets cwd + exit status.
  PROMPT='%F{blue}%~%f %(?.%F{green}.%F{red})➜%f '
fi
