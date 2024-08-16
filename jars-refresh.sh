#!/bin/bash

dir="$(dirname "$0")"

function d_start
{
    echo "Jars Refresh: starting service"
    "$dir/jars-refreshd.sh"
    echo $! > /tmp/jars-refresh.pid
    echo "PID: $(cat /tmp/jars-refresh.pid)"
}

function d_stop
{
    echo "Jars Refresh: stopping service (PID: $(cat /tmp/jars-refresh.pid))"
    kill $(cat /tmp/jars-refresh.pid)
    rm /tmp/jars-refresh.pid
 }

function d_status
{
    ps -ef | grep jars-refreshd.sh | grep -v grep
    echo "PID indication file $(cat /tmp/jars-refresh.pid 2>/dev/null)"
}

case "$1" in
    start )
        d_start
        ;;
    Stop )
        d_stop
        ;;
    Reload )
        d_stop
        sleep 1
        d_start
        ;;
    Status )
        d_status
        ;;
    * )
        echo "Usage: $ 0 {start | stop | reload | status}"
        exit 1
        ;;
esac

exit 0
