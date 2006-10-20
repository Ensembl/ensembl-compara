#!/usr/local//bin/bash

inifile=$1

if [ ! -f ${inifile} ]; then
    echo "Can not find ini-file '${inifile}'"
    exit 1
fi

pidfile=${inifile}.pid

if [ ! -f ${pidfile} ]; then
    echo "Can not find pid-file '${pidfile}'"
    exit 1
fi

pid=$(<${pidfile})

if ! kill -s 0 ${pid} 2>/dev/null; then
    echo "Server is not running with pid ${pid} on this machine"
    exit 1
fi

kill -s TERM ${pid}

sleep 1

if kill -s 0 ${pid} 2>/dev/null; then
    echo "Server killed, but is still running with pid ${pid}"
    exit 1
fi

echo "Server killed"
