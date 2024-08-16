#!/bin/bash

function load_portal {
    NAME="$(basename "$(echo "$1" | sed 's/.conf$//')")"

    if [ -e "refresh/global.conf" ]; then
        source "refresh/global.conf"
    fi

    for c in $("$dir/read-portal.php" --etc-dir=. $NAME); do eval $c; done

    if [ -e "$1" ]; then
        source "$1"
    fi

    if [ -z "$CONNECTION_STRING" ]; then
        >&2 echo "No CONNECTION_STRING set in $1"
        exit 1
    fi

    if [ -z "$AUTH_TOKEN" ]; then
        >&2 echo "No AUTH_TOKEN set in $1"
        exit 1
    fi

    for key in ${!CONNECTION_STRINGS[@]}; do
        if [ "${CONNECTION_STRINGS[$key]}" == "$CONNECTION_STRING" ]; then
            >&2 echo "Duplicate config (CONNECTION_STRING $CONNECTION_STRING)"
            exit 1
        fi
    done

    if [ -n "$PORTAL_AUTOLOAD" ]; then
        for key in ${!PORTAL_AUTOLOADS[@]}; do
            if [ "${PORTAL_AUTOLOADS[$key]}" == "$PORTAL_AUTOLOAD" ]; then
                >&2 echo "Duplicate config (PORTAL_AUTOLOAD $PORTAL_AUTOLOAD)"
                exit 1
            fi
        done
    fi

    WATCH_FILE="$(echo $CONNECTION_STRING | sed 's/[^,]*,//')/touch.dat"

    touch "$WATCH_FILE"

    if [ ! -e "$WATCH_FILE" ]; then
        >&2 echo "Watch file $WATCH_FILE does not exist, and could not be created"
        exit 1
    fi

    AUTH_TOKENS+=($AUTH_TOKEN)
    BIN_HOMES+=("$BIN_HOME")
    CONNECTION_STRINGS+=("$CONNECTION_STRING")
    PORTAL_AUTOLOADS+=("$PORTAL_AUTOLOAD")
    WATCH_FILES+=("$WATCH_FILE")

    AUTH_TOKEN=
    BIN_HOME=
    CONNECTION_STRING=
    PORTAL_AUTOLOAD=
    WATCH_FILE=
}

function refresh_portal {
    "$BIN_HOME/jars-refresh"
}
