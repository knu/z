# -*- mode: sh; sh-shell: bash; sh-basic-offset: 1 -*-
# bash tab completion
_z_bash_complete () {
 COMPREPLY=(`_z --complete "${COMP_WORDS[$COMP_CWORD]}"`)
}
complete -d -F _z_bash_complete ${_Z_CMD:-z}
[ "$_Z_NO_PROMPT_COMMAND" ] || {
 # bash populate directory list. avoid clobbering other PROMPT_COMMANDs.
 echo $PROMPT_COMMAND | grep -q "_z --add"
 [ $? -gt 0 ] && PROMPT_COMMAND='_z --add "$(pwd $_Z_RESOLVE_SYMLINKS 2>/dev/null)" 2>/dev/null;'"$PROMPT_COMMAND"
}
