# -*- mode: sh; sh-basic-offset: 1 -*-
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
