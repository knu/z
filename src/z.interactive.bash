# -*- mode: sh; sh-shell: bash; sh-basic-offset: 1 -*-
[[ -n "$_Z_NO_PROMPT_COMMAND" || "$PROMPT_COMMAND" == *'_z_cmd --add '* ]] ||
PROMPT_COMMAND='_z_cmd --add "$(pwd $_Z_RESOLVE_SYMLINKS 2>/dev/null)" 2>/dev/null;'"$PROMPT_COMMAND"

# bash tab completion
_z_bash_complete () {
 COMPREPLY=($(
  _z_cmd -lr | awk -v q="${COMP_WORDS[$COMP_CWORD]}" -F"|" '
   BEGIN {
    if (q == tolower(q)) nocase = 1
    split(q, fnd, " ")
    home = ENVIRON["HOME"]
   }
   {
    sub(/^[^\/]+/, "", $0)
    x = $0
    if (q !~ /^\// && substr(x, 0, length(home) + 1) == home "/") {
     x = substr(x, length(home) + 1)
    }
    if (nocase) x = tolower(x)
    for (i in fnd) if (!index(x, fnd[i])) next
    print
   }
  ' 2>/dev/null
 ))
}

complete -d -F _z_bash_complete ${_Z_CMD}
