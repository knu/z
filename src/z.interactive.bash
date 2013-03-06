# -*- mode: sh; sh-shell: bash; sh-basic-offset: 1 -*-
[[ -n "$_Z_NO_PROMPT_COMMAND" || "$PROMPT_COMMAND" == *'_z_cmd --add '* ]] ||
PROMPT_COMMAND='_z_cmd --add "$(pwd $_Z_RESOLVE_SYMLINKS 2>/dev/null)" 2>/dev/null;'"$PROMPT_COMMAND"

# bash tab completion
__z_cmd () {
 local pat nohome score dir LF=$'\n' IFS
 if (( COMP_CWORD == 1 )); then
  pat="${COMP_WORDS[$COMP_CWORD]}"
  if [[ $pat == //* ]]; then
   pat="/${pat#//}"
  else
   nohome=t
   pat="*$pat"
  fi
  if [[ $pat == *// ]]; then
   pat="${pat%//}/"
  else
   pat="$pat*"
  fi
  IFS=$LF
  COMPREPLY=($(
    if [[ $BASH_VERSION == 4.* ]]; then
     [[ "$pat" = "${pat,,}" ]]
    else
     awk -v s="$pat" 'BEGIN{exit(s!=tolower(s))}'
    fi && shopt -s nocasematch
    _z_cmd -lr | while IFS=' ' read -r score dir; do
     x="$dir/"
     [[ -n "$nohome" && "$x" == "$HOME/"* ]] && x="${x#"$HOME"}"
     if [[ "$x" == $pat ]]; then
      printf '%q\n' "$dir"
     fi
    done
  ))
 fi
}

complete -d -F __z_cmd ${_Z_CMD}
