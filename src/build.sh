#!/bin/sh

cd "${0%/*}" || exit

SPC=' '
TAB='	'
LF='
'
MODECOMMENT=

include_file () {
    local file="$1" indent="$2" heredoc=

    while IFS=$LF read -r line; do
        if [ -n "$heredoc" ]; then
            printf '%s\n' "$line"
            if [ "$line" = "$heredoc" ]; then
                heredoc=
            fi
            continue
        fi
        IFS="$SPC$TAB$LF" set -- $line
        if [ . = "$1" -a -f ./"$2" ]; then
            include_file ./"$2" "$indent${line%%[^$SPC$TAB]*}"
            continue
        fi
        case "$line" in
            '# -*- '*)
                if [ -z "$MODECOMMENT" ]; then
                    echo "$indent$line"
                    MODECOMMENT=t
                fi
                continue
                ;;
            *[^$SPC$TAB]*)
                printf '%s\n' "$indent$line"
                ;;
            *)
                echo
                ;;
        esac
        for arg; do
            case "$arg" in
                \<\<*\"|\<\<\'*\')
                    heredoc="${arg#<<?}"
                    heredoc="${heredoc%?}"
                    break
                    ;;
                \<\<*)
                    heredoc="${arg#<<}"
                    break
                    ;;
            esac
        done
    done < "$file"
}

include_file "$1"
