# -*- mode: sh; sh-basic-offset: 1 -*-
# Copyright (c) 2009 rupa deadwyler under the WTFPL license
# Copyright (c) 2013 Akinori MUSHA under the WTFPL license

# maintains a jump-list of the directories you actually use
#
# INSTALL:
#   * put something like this in your .bashrc/.zshrc:
#     . /path/to/z.sh
#   * cd around for a while to build up the db
#   * PROFIT!!
#   * optionally:
#     set $_Z_CMD in .bashrc/.zshrc to change the command (default z).
#     set $_Z_DATA in .bashrc/.zshrc to change the datafile (default ~/.z).
#     set $_Z_NO_RESOLVE_SYMLINKS to prevent symlink resolution.
#     set $_Z_NO_PROMPT_COMMAND if you're handling PROMPT_COMMAND yourself.
#     set $_Z_EXCLUDE_DIRS to an array of directories to exclude.
#
# USE:
#   * z foo     # cd to most frecent dir matching foo
#   * z foo bar # cd to most frecent dir matching foo and bar
#   * z -r foo  # cd to highest ranked dir matching foo
#   * z -t foo  # cd to most recently accessed dir matching foo
#   * z -l foo  # list top 10 dirs matching foo (sorted by frecency)
#   * z -l | less # list all dirs (sorted by frecency)
#   * z -c foo  # restrict matches to subdirs of $PWD

case $- in
 *i*)
  # Guard against Bash, which reads .bashrc even in a noninteractive
  # session (e.g. via ssh)
  [ -n "${PS1+t}" ] || return
  ;;
 *)
  echo 'ERROR: z.sh is meant to be sourced, not directly executed.' >&2
  exit 1
esac

: ${_Z_CMD:=z} ${_Z_DATA:=$HOME/.z}

[ -e "$_Z_DATA" -a ! -f "$_Z_DATA" ] && {
 echo "ERROR: $_Z_CMD's datafile ($_Z_DATA) is not a regular file."
 ls -ld "$_Z_DATA"
} >&2

_z_cmd () {
 local datafile="$_Z_DATA"

 # bail out if we don't own ~/.z (we're another user but our ENV is still set)
 [ -f "$datafile" -a ! -O "$datafile" ] && return

 # add entries
 case "$1" in
  --mktemp)
   mktemp "$datafile.XXXXXX" 2>/dev/null && return
   (
    set -o noclobber
    while :; do
     tmp="$datafile.$RANDOM"
     if : >"$tmp"; then
      echo "$tmp"
      exit
     fi
    done
   ) 2>/dev/null
   return
   ;;
  --add)
   shift

   local arg
   if [ $# -gt 1 ]; then
    for arg; do
     _z_cmd --add "$arg"
    done
    return
   fi
   arg="$1"

   case "$arg" in
    [^/]*|*//*|*/)
     arg="$(cd "$arg" 2>/dev/null && pwd $_Z_RESOLVE_SYMLINKS)" || return
     ;;
   esac

   # $HOME isn't worth matching
   [ "$arg" = "$HOME" ] && return

   # don't track excluded dirs
   local exclude
   for exclude in "${_Z_EXCLUDE_DIRS[@]}"; do
    case "$exclude" in
     */)
      case "$arg" in
       "${exclude%/}"|"$exclude"*) return ;;
      esac
      ;;
     *)
      [ "$arg" = "$exclude" ] && return
      ;;
    esac
   done

   [ -f "$datafile" ] || touch "$datafile"

   # maintain the data file
   local tempfile
   tempfile="$(_z_cmd --mktemp)" || return
   <"$datafile" awk -v path="$arg" -v now="$(date +%s)" -F"|" '
    $2 >= 1 {
     rank[$1] = $2
     time[$1] = $3
     count += $2
    }
    END {
     rank[path] += 1
     time[path] = now
     # aging
     if (count > 6000)
      for (x in rank) rank[x] *= 0.99
     for (x in rank) print x "|" rank[x] "|" time[x]
    }
   ' 2>/dev/null >|"$tempfile" && \
    mv -f "$tempfile" "$datafile"
   rm -f "$tempfile"
   ;;
  --del|--delete)
   shift

   local arg
   if [ $# -gt 1 ]; then
    for arg; do
     _z_cmd --delete "$arg"
    done
    return
   fi
   arg="$1"

   case "$arg" in
    [^/]*|*//*|*/)
     arg="$(cd "$arg" 2>/dev/null && pwd $_Z_RESOLVE_SYMLINKS)" || return
     ;;
   esac

   if [ -f "$datafile" ]; then
    local tempfile
    tempfile="$(_z_cmd --mktemp)" || return
    <"$datafile" awk -v dir="$arg" -F"|" '$1 != dir' 2>/dev/null >|"$tempfile" && \
     mv -f "$tempfile" "$datafile"
    rm -f "$tempfile"
   else
    touch "$datafile"
   fi
   ;;
  *)
   # list/go
   local opt OPTIND=1
   local list rev typ fnd cd limit
   while getopts hclrtx opt; do
    case "$opt" in
     c) fnd="/$PWD/";;
     l) list=1;;
     r) typ="rank";;
     t) typ="recent";;
     x) _z_cmd --del "$PWD";;
     *) cat <<EOF >&2
$_Z_CMD [-clrtx] [args...]

    -h          show this help
    -c          restrict matches to subdirectories of the current directory
    -l          list dirs (matching args if given)
    -r          sort dirs by rank
    -t          sort dirs by recency
    -x          remove the current directory from the datafile

    Omitting args implies -l.
EOF
      [ $opt = h ]; return;;
    esac
   done
   shift $((OPTIND-1))

   case $# in
    0) list=1;;
    1)
     # if we hit enter on a completion just go there;
     # completions will always start with /
     if [[ -z "$list" && "$1" == /* && -d "$1" ]]; then
      cd "$1" && return
     fi
     ;;
   esac

   fnd="${fnd:+$fnd }$*"

   # no file yet
   [ -f "$datafile" ] || return

   # show only top 20 if stdout is a terminal
   [ -t 1 ] && limit=20

   cd="$(while read line; do
    # only count directories
    [ -d "${line%%\|*}" ] && echo "$line"
   done <"$datafile" | awk -v t="$(date +%s)" -v list="$list" -v typ="$typ" -v q="$fnd" -v limit="$limit" -F"|" '
    function frecent(rank, time) {
     # relate frequency and time
     dx = t - time
     if (dx < 3600) return rank * 4
     if (dx < 86400) return rank * 2
     if (dx < 604800) return rank / 2
     return rank / 4
    }
    function output(files, out, common) {
     # list or return the desired directory
     if (list) {
      if (common) {
       printf "%-10s %s\n", max, common
       if (limit) limit--
      }
      cmd = "sort -nr"
      if (limit) cmd = cmd " | head -n" limit
      for (x in files) {
       file = files[x]
       if (file > max) file = max
       if (file && x != common) printf "%-10s %s\n", file, x | cmd
      }
     } else {
      if (common) out = common
      print out
     }
    }
    function common(matches) {
     # find the common root of a list of matches, if it exists
     for (x in matches) {
      if (matches[x] && (!short || length(x) < length(short))) short = x
     }
     if (short == "/") return
     # use a copy to escape special characters, as we want to return
     # the original. yeah, this escaping is awful.
     clean_short = short
     gsub(/[\(\)\[\]\|]/, "\\\\&", clean_short)
     for (x in matches) if (matches[x] && x !~ clean_short) return
     return short
    }
    BEGIN {
     max = 9999999999
     hi_rank = ihi_rank = -max
     split(q, words, " ")
     homepfx = ENVIRON["HOME"] "/"
    }
    function xmatch(s, pat, nc, pfx, sfx,  x) {
     if (nc) { s = tolower(s); pat = tolower(pat); }
     x = index(s, pat)
     return x && \
            (!pfx || x == 1) && \
            (!sfx || x - 1 + length(pat) == length(s))
    }
    {
     if (typ == "rank")
      rank = $2
     else if (typ == "recent")
      rank = $3 - t
     else
      rank = frecent($2, $3)
     matches[$1] = imatches[$1] = rank
     for (x in words) {
      pat = words[x]
      x = $1 "/"
      pfx = sfx = 0
      if (sub(/^\/\//, "/", pat)) pfx = 1
      if (sub(/\/\/$/, "/", pat)) sfx = 1
      if (!pfx && substr(x, 1, length(homepfx)) == homepfx)
       x = substr(x, length(homepfx) - 1)
      if (!xmatch(x, pat, 0, pfx, sfx)) delete matches[$1]
      if (!xmatch(x, pat, 1, pfx, sfx)) delete imatches[$1]
     }
     if (matches[$1] && matches[$1] > hi_rank) {
      best_match = $1
      hi_rank = matches[$1]
     } else if (imatches[$1] && imatches[$1] > ihi_rank) {
      ibest_match = $1
      ihi_rank = imatches[$1]
     }
    }
    END {
     if (best_match)
      output(matches, best_match, common(matches))
     else if (ibest_match)
      output(imatches, ibest_match, common(imatches))
    }
   ')" || return
   if [ -n "$list" ]; then
    cat <<EOF
$cd
EOF
   else
    [ -d "$cd" ] && cd "$cd"
   fi
   ;;
 esac
}

alias ${_Z_CMD}=_z_cmd

[ "$_Z_NO_RESOLVE_SYMLINKS" ] || _Z_RESOLVE_SYMLINKS="-P"

if [ -n "$BASH_VERSION" ]; then
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
 return
fi

if [[ "${ZSH_VERSION-0.0}" != [0-3].* ]]; then
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
fi
