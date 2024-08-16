#!/bin/bash

dir="$(dirname "$0")"

source "$dir/functions.sh"

if [ "refresh/conf.d/*.conf" == "refresh/conf.d/\\*.conf" ]; then
    >&2 echo "No configs to monitor"
    exit 1
fi

for conf_file in refresh/conf.d/*.conf; do
    load_portal "$conf_file"
done

for key in ${!WATCH_FILES[@]}; do
    if [[ "$OSTYPE" =~ ^darwin ]]; then
        FILE_ARGS="$FILE_ARGS ${WATCH_FILES[$key]} "
    else
        FILE_ARGS="$FILE_ARGS-m ${WATCH_FILES[$key]} "
    fi
done

for key in ${!CONNECTION_STRINGS[@]}; do
    export AUTH_TOKEN="${AUTH_TOKENS[$key]}"
    export BIN_HOME="${BIN_HOMES[$key]}"
    export CONNECTION_STRING="${CONNECTION_STRINGS[$key]}"
    export PORTAL_AUTOLOAD="${PORTAL_AUTOLOADS[$key]}"

    refresh_portal
done

rm -rf /tmp/jars-refreshd.fifo
mkfifo /tmp/jars-refreshd.fifo

while true; do
    if [[ "$OSTYPE" =~ ^darwin ]]; then
        fswatch $FILE_ARGS > /tmp/jars-refreshd.fifo 2>/dev/null &
    else
        inotifywait -e CLOSE_WRITE,DELETE_SELF $FILE_ARGS > /tmp/jars-refreshd.fifo 2>/dev/null &
    fi

    PID=$!

    while read f e; do
        FOUND=

        for key in ${!WATCH_FILES[@]}; do
            if [ "${WATCH_FILES[$key]}" == "$f" ]; then
                FOUND=1

                export AUTH_TOKEN="${AUTH_TOKENS[$key]}"
                export BIN_HOME="${BIN_HOMES[$key]}"
                export CONNECTION_STRING="${CONNECTION_STRINGS[$key]}"
                export PORTAL_AUTOLOAD="${PORTAL_AUTOLOADS[$key]}"
                export WATCH_FILE="${WATCH_FILES[$key]}"
            fi
        done

        if [ -z "$FOUND" ]; then
            >&2 echo "Internal error"
            exit 1
        fi

        if [[ "$OSTYPE" =~ ^darwin ]] && [[ "$e" =~ Renamed ]] || [ "$e" == "DELETE_SELF" ] ; then
            kill $PID

            while [ ! -e "$WATCH_FILE" ]; do
                sleep 1
            done

            refresh_portal
            break
        fi

        refresh_portal
    done < /tmp/jars-refreshd.fifo
done
