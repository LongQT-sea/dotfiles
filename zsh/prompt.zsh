# =========================================================
# Prompt
# =========================================================

export VIRTUAL_ENV_DISABLE_PROMPT=1   # keep venv out of the prompt

FUNCNEST=100

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
else
  # Fallback so a box without starship still gets cwd + exit status.
  PROMPT='%F{blue}%~%f %(?.%F{green}.%F{red})➜%f '
fi
