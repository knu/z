#!/bin/sh

cd "${0%/*}" || exit

SPC=' '
TAB='	'
LF='
'

while IFS=$LF read -r line; do
    IFS="$SPC$TAB$LF" set -- $line
    if [ "$1" = . -a -f ./"$2" ]; then
        indent="${line%%[^$SPC$TAB]*}"
        while IFS=$LF read -r line; do
            case "$line" in
                '# -*- '*)
                    continue
                    ;;
                *[^$SPC$TAB]*)
                    echo "$indent$line"
                    ;;
                -*)
                    printf %s "$line"
                    ;;
                *)
                    echo
                    ;;
            esac
        done < ./"$2"
    else
        case "$line" in
            -*)
                printf %s "$line"
                ;;
            *)
                echo "$line"
                ;;
        esac
    fi
done < z.main.sh > ../z.sh
