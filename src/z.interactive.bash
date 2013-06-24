# -*- mode: sh; sh-shell: bash; sh-basic-offset: 1 -*-
[[ -n "$_Z_NO_PROMPT_COMMAND" || "$PROMPT_COMMAND" == *'_z_cmd --add '* ]] ||
PROMPT_COMMAND='_z_cmd --add "$(pwd $_Z_RESOLVE_SYMLINKS 2>/dev/null)" 2>/dev/null'"${PROMPT_COMMAND:+$'\n'}$PROMPT_COMMAND"

_z_stack () {
 local pat nohome score dir
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
  local IFS=$'\n'
  COMPREPLY+=($(
    if [[ $BASH_VERSION == 4.* ]]; then
     [[ "$pat" = "${pat,,}" ]]
    else
     awk -v s="$pat" 'BEGIN{exit(s!=tolower(s))}'
    fi && shopt -s nocasematch
    _z_cmd -lr | while IFS=' ' read -r score dir; do
     x="$dir/"
     [[ -n "$nohome" && "$x" == "$HOME/"* ]] && x="${x#"$HOME"}"
     if [[ "$x" == $pat ]]; then
      printf '%q\n' "${dir/#"$HOME"\//~/}"
     fi
    done
  ))
 fi
}

_z_dirs () {
 if declare -f _filedir >/dev/null; then
  cur="${COMP_WORDS[$COMP_CWORD]}" _filedir -d
 else
  local IFS=$'\n'
  COMPREPLY+=($(
    compgen -d -- "${COMP_WORDS[$COMP_CWORD]}" | while read -r dir; do
     printf "%q\n" "${dir/#"$HOME"\//~/}"
    done
  ))
 fi
}

__z_cmd () {
  _z_stack
  _z_dirs
}

complete -o nospace -F __z_cmd ${_Z_CMD}

__z_complete_cd () {
 local func
 set -- $(complete -p cd 2>/dev/null)

 while (( $# )); do
  case "$1" in
   -[oAGWCXPS]) shift 2 ;;
   -F) func="$2"; break ;;
   -*) shift ;;
   *)  break ;;
  esac
 done

 eval "_cd_z () { ${func:-_z_dirs}; (( \${#COMPREPLY} > 0 )) || _z_stack; }"
}; __z_complete_cd; unset -f __z_complete_cd

[[ -n "$_Z_NO_COMPLETE_CD" ]] || {
 complete -o nospace -F _cd_z cd
}
