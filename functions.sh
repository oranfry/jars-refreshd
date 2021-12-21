
function load_portal {
    source "$1"

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

    if [ ! -e "$WATCH_FILE" ]; then
        echo "Watch file $WATCH_FILE does not exist"
        exit
    fi

    DB_HOMES+=($DB_HOME)
    AUTH_TOKENS+=($AUTH_TOKEN)
    PORTAL_HOMES+=($PORTAL_HOME)
    WATCH_FILES+=("$WATCH_FILE")

    DB_HOME=
    PORTAL_HOME=
    AUTH_TOKEN=
    WATCH_FILE=
}


function refresh_portal {
    PORTAL_HOME="$1"
    AUTH_TOKEN="$2"

    "$PORTAL_HOME/cli.php" refresh -t $AUTH_TOKEN
}