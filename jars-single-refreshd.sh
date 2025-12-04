#!/bin/bash

dir="$(dirname "$0")"

WATCH_FILE=$($JARS_BIN info -e TOUCH_FILE)
touch "$WATCH_FILE"

if [ ! -e "$WATCH_FILE" ]; then
    >&2 echo "Watch file $WATCH_FILE does not exist, and could not be created"
    exit 1
fi

$JARS_BIN refresh

trap "exit;" SIGINT SIGTERM

while true; do
    (
        if [[ "$OSTYPE" =~ ^darwin ]]; then
            fswatch "$WATCH_FILE" 2>/dev/null
        else
            inotifywait -e CLOSE_WRITE,DELETE_SELF -m "$WATCH_FILE" 2>/dev/null
        fi
    ) | while read f e; do
        if [[ "$OSTYPE" =~ ^darwin ]] && [[ "$e" =~ Renamed ]] || [ "$e" == "DELETE_SELF" ] ; then
            kill $PID

            while [ ! -e "$WATCH_FILE" ]; do
                sleep 1
            done

            $JARS_BIN refresh
            break
        fi

        $JARS_BIN refresh
    done
done
