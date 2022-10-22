
function load_portal {
    NAME="$(basename "$(echo "$1" | sed 's/.conf$//')")"

    source "$1"
    source "global.conf"

    if [ -z "$DB_HOME" ]; then
        echo "No DB_HOME set in $1"
        exit
    fi

    if [ -z "$PORTAL_HOME" ]; then
        echo "No PORTAL_HOME set in $1"
        exit
    fi

    if [ -z "$AUTH_TOKEN" ]; then
        echo "No AUTH_TOKEN set in $1"
        exit
    fi

    for key in ${!DB_HOMES[@]}; do
        if [ "${DB_HOMES[$key]}" == "$DB_HOME" ]; then
            echo "Duplicate config (DB_HOME $DB_HOME)"
            exit
        fi
    done

    for key in ${!PORTAL_HOMES[@]}; do
        if [ "${PORTAL_HOMES[$key]}" == "$PORTAL_HOME" ]; then
            echo "Duplicate config (PORTAL_HOME $PORTAL_HOME)"
            exit
        fi
    done

    WATCH_FILE="$DB_HOME/touch.dat"

    touch "$WATCH_FILE"

    if [ ! -e "$WATCH_FILE" ]; then
        echo "Watch file $WATCH_FILE does not exist, and could not be created"
        exit
    fi

    AUTH_TOKENS+=($AUTH_TOKEN)
    BIN_HOMES+=("$BIN_HOME")
    DB_HOMES+=("$DB_HOME")
    NAMES+=($NAME)
    PORTAL_HOMES+=("$PORTAL_HOME")
    WATCH_FILES+=("$WATCH_FILE")

    AUTH_TOKEN=
    BIN_HOME=
    DB_HOME=
    NAME=
    PORTAL_HOME=
    WATCH_FILE=
}

function refresh_portal {
    "$BIN_HOME/jars-refresh" $1
}
