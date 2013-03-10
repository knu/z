# -*- mode: sh; sh-basic-offset: 1 -*-
local datafile="${_Z_DATA:-$HOME/.z}"

# bail out if we don't own ~/.z (we're another user but our ENV is still set)
[ -f "$datafile" -a ! -O "$datafile" ] && return

# add entries
case "$1" in
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

  # maintain the file
  local tempfile
  tempfile="$(mktemp $datafile.XXXXXX)" || return
  <"$datafile" awk -v path="$arg" -v now="$(date +%s)" -F"|" '
   $2 >= 1 {
    rank[$1] = $2
    time[$1] = $3
    count += $2
   }
   END {
    rank[path] += 1
    time[path] = now
    if (count > 6000)
     for (i in rank) rank[i] *= 0.99
    for (i in rank) print i "|" rank[i] "|" time[i]
   }
  ' 2>/dev/null >| "$tempfile"
  if [ $? -ne 0 -a -f "$datafile" ]; then
   env rm -f "$tempfile"
  else
   env mv -f "$tempfile" "$datafile"
  fi
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
   tempfile="$(mktemp $datafile.XXXXXX)" || return
   < "$datafile" awk -v dir="$arg" -F"|" '$1 != dir' 2>/dev/null >| "$tempfile"
   if [ $? -ne 0 -a -f "$datafile" ]; then
    env rm -f "$tempfile"
   else
    env mv -f "$tempfile" "$datafile"
   fi
  else
   touch "$datafile"
  fi
  ;;
 *)
  # list/go
  local opt OPTIND=1
  local list rev typ fnd cd limit
  while getopts hclrt opt; do
   case "$opt" in
    c) fnd="/$PWD/";;
    l) list=1;;
    r) typ="rank";;
    t) typ="recent";;
    *) cat <<EOF >&2
$_Z_CMD [-clrt] [args...]

    -h          show this help
    -c          restrict matches to subdirectories of the current directory
    -l          list dirs (matching args if given)
    -r          sort dirs by rank
    -t          sort dirs by recency

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

  # show only top 10 if stdout is a terminal
  [ -t 1 ] && limit=10

  cd="$(while read line; do
   [ -d "${line%%\|*}" ] && echo "$line"
  done < "$datafile" | awk -v t="$(date +%s)" -v list="$list" -v typ="$typ" -v q="$fnd" -v limit="$limit" -F"|" '
   function frecent(rank, time) {
    dx = t - time
    if (dx < 3600) return rank * 4
    if (dx < 86400) return rank * 2
    if (dx < 604800) return rank / 2
    return rank/4
   }
   function output(files, toopen, override) {
    if (list) {
     if (override) {
      printf "%-10s %s\n", max, override
      if (limit) limit--
     }
     cmd = "sort -nr"
     if (limit) cmd = cmd " | head -n" limit
     for (i in files) {
      file = files[i]
      if (file > max) file = max
      if (file && i != override) printf "%-10s %s\n", file, i | cmd
     }
    } else {
     if (override) toopen = override
     print toopen
    }
   }
   function common(matches) {
    # shortest match
    for (i in matches) {
     if (matches[i] && (!short || length(i) < length(short))) short = i
    }
    if (short == "/") return
    # shortest match must be common to each match. escape special characters in
    # a copy when testing, so we can return the original.
    clean_short = short
    gsub(/[\(\)\[\]\|]/, "\\\\&", clean_short)
    for (i in matches) if (matches[i] && i !~ clean_short) return
    return short
   }
   BEGIN {
    max = 9999999999
    oldf = noldf = -max
    split(q, a, " ")
    homepfx = ENVIRON["HOME"] "/"
   }
   function xmatch(s, pat, nc, pfx, sfx,  i) {
    if (nc) { s = tolower(s); pat = tolower(pat); }
    i = index(s, pat)
    return i && \
           (!pfx || i == 1) && \
           (!sfx || i - 1 + length(pat) == length(s))
   }
   {
    if (typ == "rank") {
     f = $2
    } else if (typ == "recent") {
     f = $3 - t
    } else f = frecent($2, $3)
    wcase[$1] = nocase[$1] = f
    for (i in a) {
     x = $1 "/"
     pat = a[i]
     pfx = sfx = 0
     if (sub(/^\/\//, "/", pat)) pfx = 1
     if (sub(/\/\/$/, "/", pat)) sfx = 1
     if (!pfx && substr(x, 1, length(homepfx)) == homepfx)
      x = substr(x, length(homepfx) - 1)
     if (!xmatch(x, pat, 0, pfx, sfx)) delete wcase[$1]
     if (!xmatch(x, pat, 1, pfx, sfx)) delete nocase[$1]
    }
    if (wcase[$1] && wcase[$1] > oldf) {
     cx = $1
     oldf = wcase[$1]
    } else if (nocase[$1] && nocase[$1] > noldf) {
     ncx = $1
     noldf = nocase[$1]
    }
   }
   END {
    if (cx) {
     output(wcase, cx, common(wcase))
    } else if (ncx) output(nocase, ncx, common(nocase))
   }
  ')"
  [ $? -gt 0 ] && return
  if [ -n "$list" ]; then
   cat <<EOF
$cd
EOF
  else
   [ -d "$cd" ] && cd "$cd"
  fi
  ;;
esac
