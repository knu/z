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
 . z.cli.sh "$@"
}

alias ${_Z_CMD}=_z_cmd

[ "$_Z_NO_RESOLVE_SYMLINKS" ] || _Z_RESOLVE_SYMLINKS="-P"

if [ -n "$BASH_VERSION" ]; then
 . z.interactive.bash
 return
fi

if [[ "${ZSH_VERSION-0.0}" != [0-3].* ]]; then
 . z.interactive.zsh
fi
