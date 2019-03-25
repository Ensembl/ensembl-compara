#!/bin/bash

[ $# -ne 2 ] && { echo "Usage: $0 mysql-server database_name"; exit 1; }

set -euo pipefail

"$1" "$2" --column-names=false -e "SHOW FULL TABLES WHERE TABLE_TYPE = 'BASE TABLE'" | cut -f1 | while read table; do
    echo "$table"
    "$1" "$2" -e "ALTER TABLE $2.$table ENABLE KEYS"
done

