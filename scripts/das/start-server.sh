#!/usr/local/bin/bash

inifile=$1

if [ ! -f ${inifile} ]; then
    echo "Can not find ini-file '${inifile}'"
    exit 1
fi

proserver -c ${inifile}

logfile=${inifile}.log

if [ ! -f ${logfile} ]; then
    echo "Can not find log-file '${logfile}'"
    exit 1
fi

echo "==>"
echo "==> Now viewing '${logfile}'..."
echo "==> Press <ctrl>-C to stop looking at the log file"
echo "==> Run './kill-server.ksh ${inifile}' to stop the server"
echo "==>"

tail -f ${logfile}
