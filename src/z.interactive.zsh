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
_z () {
 emulate -L zsh
 setopt extended_glob
 local qword word x
 local -a list qlist
 if (( CURRENT == 2 )); then
  qword=${words[$CURRENT]}
  word=${~qword}
  list=(${(f)"$(
   _z_cmd -lr | awk -v q="$word" -F"|" '
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
  )"})
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

compdef _z _z_cmd
