#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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


[ $# -ne 2 ] && { echo "Usage: $0 mysql-server database_name"; exit 1; }

set -euo pipefail

"$1" "$2" --column-names=false -e "SHOW FULL TABLES WHERE TABLE_TYPE = 'BASE TABLE'" | cut -f1 | while read table; do
    echo "$table"
    "$1" "$2" -e "ALTER TABLE $2.$table ENABLE KEYS"
done

