# -*- mode: sh; sh-shell: zsh; sh-basic-offset: 1 -*-
[ "$_Z_NO_PROMPT_COMMAND" ] || {
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

# zsh tab completion
__z_cmd () {
 emulate -L zsh
 setopt extended_glob
 local pat nohome score dir
 local -a qlist
 if (( CURRENT == 2 )); then
  pat=${words[$CURRENT]}
  if [[ $pat == //* ]]; then
   pat="/${pat##/#}"
  else
   nohome=t
   pat="*$pat"
  fi
  if [[ $pat == *// ]]; then
   pat="${pat%%/#}"
  else
   pat="$pat*"
  fi
  pat="(#l)$pat"
  _z_cmd -lr | while read -r score dir; do
   x="${dir#"${nohome:+$HOME/}"}"
   if [[ "$x" == ${~pat} ]]; then
    hash -d x= dir=
    qlist+=(${(D)dir})
   fi
  done
  _alternative \
   'z:z stack:compadd -d qlist -U -l -Q -- "${qlist[@]}"' \
   'd:directory:_path_files -/'
  compstate[insert]=menu
 fi
}

compdef __z_cmd _z_cmd
