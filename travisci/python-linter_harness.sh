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

PYTHON_SOURCE_LOCATIONS=('scripts')

PYLINT_OUTPUT_FILE=$(mktemp)
PYLINT_ERRORS=$(mktemp)
pylint --rcfile pylintrc --verbose "${PYTHON_SOURCE_LOCATIONS[@]}" | tee "$PYLINT_OUTPUT_FILE"
grep -v "\-\-\-\-\-\-\-\-\-" "$PYLINT_OUTPUT_FILE" | grep -v "Your code has been rated" | grep -v "\n\n" | sed '/^$/d' > "$PYLINT_ERRORS"
! [ -s "$PYLINT_ERRORS" ]
rt1=$?
rm "$PYLINT_OUTPUT_FILE" "$PYLINT_ERRORS"

find "${PYTHON_SOURCE_LOCATIONS[@]}" -name "*.py" -print0 | xargs -0 mypy
rt2=$?

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) ]]; then
  exit 0
else
  exit 255
fi
