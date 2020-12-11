#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

# Setup the environment variables
export ENSADMIN_PSW='dummy_pwd'
# shellcheck disable=SC2155
export PYTHONPATH=$PYTHONPATH:$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')

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
pytest "${PYTEST_OPTIONS[@]}" "${PYTHON_TESTS_LOCATIONS[@]}" --ignore="src/python/tests/test_db.py" --server="mysql://travis@127.0.0.1:3306/"
rt2=$?
if [ "$COVERAGE" = 'true' ]; then
  PYTEST_OPTIONS+=('--cov-append')
fi
pytest "${PYTEST_OPTIONS[@]}" src/python/tests/test_db.py --server="mysql://travis@127.0.0.1:3306/"
rt4=$?
# Test SQLite-specific code
if [ "$COVERAGE" = 'true' ]; then
  PYTEST_OPTIONS+=('--cov-append' '-k UnitTestDB')
  pytest "${PYTEST_OPTIONS[@]}" src/python/tests/test_db.py --server="sqlite:////tmp/"
  rt3=$?
else
  rt3=0
fi

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) && ($rt3 -eq 0) && ($rt4 -eq 0) ]]; then
  exit 0
else
  exit 255
fi
