
function load_portal {
    NAME="$(basename "$(echo "$1" | sed 's/.conf$//')")"

    for c in $("$dir/read-portal.php" $NAME); do export $c; done

    source "$1"
    source "refresh/global.conf"

    if [ -z "$CONNECTION_STRING" ]; then
        echo "No CONNECTION_STRING set in $1"
        exit
    fi

    if [ -z "$AUTH_TOKEN" ]; then
        echo "No AUTH_TOKEN set in $1"
        exit
    fi

    for key in ${!CONNECTION_STRINGS[@]}; do
        if [ "${CONNECTION_STRINGS[$key]}" == "$CONNECTION_STRING" ]; then
            echo "Duplicate config (CONNECTION_STRING $CONNECTION_STRING)"
            exit
        fi
    done

    for key in ${!PORTAL_AUTOLOADS[@]}; do
        if [ "${PORTAL_AUTOLOADS[$key]}" == "$PORTAL_AUTOLOAD" ]; then
            echo "Duplicate config (PORTAL_AUTOLOAD $PORTAL_AUTOLOAD)"
            exit
        fi
    done

    WATCH_FILE="$(echo $CONNECTION_STRING | sed 's/[^,]*,//')/touch.dat"

    touch "$WATCH_FILE"

    if [ ! -e "$WATCH_FILE" ]; then
        echo "Watch file $WATCH_FILE does not exist, and could not be created"
        exit
    fi

    AUTH_TOKENS+=($AUTH_TOKEN)
    BIN_HOMES+=("$BIN_HOME")
    CONNECTION_STRINGS+=("$CONNECTION_STRING")
    NAMES+=($NAME)
    WATCH_FILES+=("$WATCH_FILE")

    AUTH_TOKEN=
    BIN_HOME=
    CONNECTION_STRING=
    NAME=
    WATCH_FILE=
}

function refresh_portal {
    "$BIN_HOME/jars-refresh" $1
}
