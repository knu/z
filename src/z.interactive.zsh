# -*- mode: sh; sh-shell: zsh; sh-basic-offset: 1 -*-
[ "$_Z_NO_PROMPT_COMMAND" ] || {
 # zsh populate directory list, avoid clobbering any other precmds
 if [ "$_Z_NO_RESOLVE_SYMLINKS" ]; then
  _z_precmd() {
   _z --add "${PWD:a}"
  }
 else
  _z_precmd() {
   _z --add "${PWD:A}"
  }
 fi
 precmd_functions+=(_z_precmd)
}
# zsh tab completion
_z_zsh_tab_completion() {
 emulate -L zsh
 setopt extended_glob
 local qword word x
 local -a list qlist
 if (( CURRENT == 2 )); then
  qword=${words[$CURRENT]}
  word=${~qword}
  list=(${(f)"$(_z --complete "$word")"})
  for x in $list; do
   hash -d x= qword= word=
   qlist+=(${(D)x})
  done
  _alternative \
   'z:z stack:compadd -d qlist -U -l -Q -- "${qlist[@]}"' \
   'd:directory:_path_files -/'
  compstate[insert]=menu
 fi
}
compdef _z_zsh_tab_completion _z
