#!/bin/bash

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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


[ $# -ne 4 ] && { echo "Usage: $0 --host=mysql-server --port=port --user=user database_name"; exit 1; }

set -euo pipefail

mysql "$@" --column-names=false -e "SHOW FULL TABLES WHERE TABLE_TYPE = 'BASE TABLE'" | cut -f1 | while read -r table; do
    echo "$table"
    mysql "$@" -e "ALTER TABLE $table ENABLE KEYS"
done

