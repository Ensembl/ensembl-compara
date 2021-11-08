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

PYTHON_SOURCE_LOCATIONS=('scripts' 'src/python')
PYTHON_TESTS_LOCATIONS=('src/python/tests/')

# Check that all the Python files can be compiled
if [ "$TEST_COMPILATION" = 'true' ]; then
  find "${PYTHON_SOURCE_LOCATIONS[@]}" -name '*.py' -print0 | xargs -0 travisci/compile.py
  rt1=$?
else
  rt1=0
fi

PYTEST_OPTIONS=()
if [ "$COVERAGE" = 'true' ]; then
  PYTEST_OPTIONS+=('--cov=./' '--cov-report=term-missing')
fi
pytest "${PYTEST_OPTIONS[@]}" -o server="mysql://travis@127.0.0.1:3306/" "${PYTHON_TESTS_LOCATIONS[@]}"
rt2=$?

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) ]]; then
  exit 0
else
  exit 255
fi
