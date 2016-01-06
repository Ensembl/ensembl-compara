#!/bin/bash
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
