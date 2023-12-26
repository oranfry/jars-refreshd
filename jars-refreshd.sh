#!/bin/bash

dir="$(dirname "$0")"

source "$dir/functions.sh"

if [ "refresh/conf.d/*.conf" == "refresh/conf.d/\\*.conf" ]; then
    echo "No configs to monitor"
    exit
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
    BIN_HOME=${BIN_HOMES[$key]}
    refresh_portal ${NAMES[$key]}
done

BIN_HOME=

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
        for key in ${!WATCH_FILES[@]}; do
            if [ "${WATCH_FILES[$key]}" == "$f" ]; then
                AUTH_TOKEN="${AUTH_TOKENS[$key]}"
                BIN_HOME="${BIN_HOMES[$key]}"
                CONNECTION_STRING="${CONNECTION_STRINGS[$key]}"
                NAME="${NAMES[$key]}"
                WATCH_FILE="${WATCH_FILES[$key]}"
            fi
        done

        if [[ "$OSTYPE" =~ ^darwin ]] && [[ "$e" =~ Renamed ]] || [ "$e" == "DELETE_SELF" ] ; then
            kill $PID

            while [ ! -e "$WATCH_FILE" ]; do
                sleep 1
            done

            refresh_portal $NAME
            break
        fi

        refresh_portal $NAME
    done < /tmp/jars-refreshd.fifo
done
