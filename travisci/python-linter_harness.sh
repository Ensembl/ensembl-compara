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

# Setup the environment variables
# shellcheck disable=SC2155
export PYTHONPATH=$PYTHONPATH:$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
# more info: https://mypy.readthedocs.io/en/stable/running_mypy.html#mapping-file-paths-to-modules
export MYPYPATH=$MYPYPATH:src/python/lib

# Function to run pylint
run_pylint() {
  local pylint_output_file=$(mktemp)

  # Run pylint, excluding specific files and directories
  find "${PYTHON_SOURCE_LOCATIONS[@]}" -type f -name "*.py" \
    \! -name "Ortheus.py" \
    \! -name "*citest*.py" \
    \! -path "*/citest/*" -print0 |
    xargs -0 pylint --rcfile=pyproject.toml --verbose \
      --msg-template='COMPARA_PYLINT_MSG:{path}:{line}:{column}: {msg_id}: {msg} ({symbol})' |
    tee "$pylint_output_file"

  # Return 1 if pylint messages were found, otherwise 0
  #  -c option counts the number of matches, -m 1 stops after the first match to optimize performance,
  local result=$(grep -c -m 1 -E '^COMPARA_PYLINT_MSG:' "$pylint_output_file")

  # Cleanup
  rm "$pylint_output_file"

  return "$result"
}

# Function to run mypy, excluding certain files and paths, and capturing the outcome
run_mypy() {
  find "${PYTHON_SOURCE_LOCATIONS[@]}" -type f -name "*.py" \
    \! -name "Ortheus.py" \
    \! -name "*citest*.py" \
    \! -path "*/citest/*" -print0 |
    xargs -0 mypy --config-file pyproject.toml --namespace-packages --explicit-package-bases
}

# Define Python source locations
PYTHON_SOURCE_LOCATIONS=('scripts' 'src/python')

# Run pylint and mypy, capturing their return codes
run_pylint
rt1=$?

run_mypy
rt2=$?

# Determine exit code based on results
if [[ $rt1 -eq 0 && $rt2 -eq 0 ]]; then
  exit 0 # success
elif [[ $rt1 -ne 0 ]]; then
  exit 1 # pylint error
elif [[ $rt2 -ne 0 ]]; then
  exit 2 # mypy error
else
  exit 3 # error on both
fi
