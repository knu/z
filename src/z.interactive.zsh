# -*- mode: sh; sh-shell: zsh; sh-basic-offset: 1 -*-
[[ -n "$_Z_NO_PROMPT_COMMAND" || -n "${precmd_functions[(r)_z_precmd]}" ]] || {
 if [ "$_Z_NO_RESOLVE_SYMLINKS" ]; then
  _z_precmd () {
   _z_cmd --add "${PWD:a}"
  }
 else
  _z_precmd () {
   _z_cmd --add "${PWD:A}"
  }
 fi
 precmd_functions+=(_z_precmd)
}

_z_stack () {
 emulate -L zsh
 setopt extended_glob
 local pat nohome score dir
 local -a qlist
 if (( CURRENT == 2 )); then
  pat=${words[$CURRENT]}
  if [[ $pat == \~* ]]; then
   pat="\\$pat"
  fi
  if [[ $pat == //* ]]; then
   pat="/${pat##/#}"
  else
   nohome=t
   pat="*$pat"
  fi
  if [[ $pat == *// ]]; then
   pat="${pat%%/#}/"
  else
   pat="$pat*"
  fi
  pat="(#l)$pat"
  _z_cmd -lr | while read -r score dir; do
   x="$dir/"
   [[ -n "$nohome" && "$x" == "$HOME/"* ]] && x="${x#"$HOME"}"
   if [[ "$x" == ${~pat} ]]; then
    hash -d x= dir=
    if is-at-least 4.3.11; then
     qlist+=(${(D)dir})
    else
     qlist+=(${dir/#"$HOME"\//\~\/})
    fi
   fi
  done
  (( ${#qlist} == 0 )) && return 1
  compadd -d qlist -U -Q "$@" -- "${qlist[@]}"
  compstate[insert]=menu
 fi
}

__z_cmd () {
 _alternative \
  'z:z stack:_z_stack -l' \
  'd:directory:_path_files -/'
}

compdef __z_cmd _z_cmd

[[ ${_comps[cd]} = _cd_z ]] ||
typeset -g _cd_z_super="${_comps[cd]:-_cd}"

_cd_z () {
 local expl
 $_cd_z_super
 _wanted z expl 'z stack' _z_stack
}

[ "$_Z_NO_COMPLETE_CD" ] || {
 zstyle ':completion:*:cd:*' group-name ''
 compdef _cd_z cd
}
