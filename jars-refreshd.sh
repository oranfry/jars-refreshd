#!/bin/bash

source functions.sh

dir="$(dirname "$0")"

if [ "$dir/conf.d/*.conf" == "$dir/conf.d/\\*.conf" ]; then
    echo "No configs to monitor"
    exit
fi

for conf_file in $dir/conf.d/*.conf; do
    load_portal "$conf_file"
done

for key in ${!WATCH_FILES[@]}; do
    FILE_ARGS="$FILE_ARGS-m ${WATCH_FILES[$key]} "
done

for key in ${!PORTAL_HOMES[@]}; do
    refresh_portal ${PORTAL_HOMES[$key]} ${AUTH_TOKENS[$key]}
done

rm -rf /tmp/jars-refreshd.fifo
mkfifo /tmp/jars-refreshd.fifo

while true; do
    inotifywait -e CLOSE_WRITE,DELETE_SELF $FILE_ARGS > /tmp/jars-refreshd.fifo 2>/dev/null &
    PID=$!

    while read f e; do
        for key in ${!WATCH_FILES[@]}; do
            if [ "${WATCH_FILES[$key]}" == "$f" ]; then
                DB_HOME="${DB_HOMES[$key]}"
                PORTAL_HOME="${PORTAL_HOMES[$key]}"
                AUTH_TOKEN="${AUTH_TOKENS[$key]}"
                WATCH_FILE="${WATCH_FILES[$key]}"
            fi
        done

        CMD="$PORTAL_HOME/cli.php refresh -t $AUTH_TOKEN"

        if [ "$e" == "DELETE_SELF" ]; then
            kill $PID

            while [ ! -e "$WATCH_FILE" ]; do
                sleep 1
            done

            refresh_portal $PORTAL_HOME $AUTH_TOKEN
            break
        fi

        refresh_portal $PORTAL_HOME $AUTH_TOKEN
    done < /tmp/jars-refreshd.fifo
done
