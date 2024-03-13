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
  local pylint_errors=$(mktemp)

  # Run pylint, excluding specific files and directories
  find "${PYTHON_SOURCE_LOCATIONS[@]}" -type f -name "*.py" \
    ! -name "Ortheus.py" \
    ! -name "*citest*.py" \
    ! -path "*/citest/*" -print0 |
    xargs -0 pylint --rcfile=pyproject.toml --verbose \
      --msg-template='{path}:{line}:{column}: {msg_id}: {msg} ({symbol})' |
    tee "$pylint_output_file"

  # Keep only lines with pylint messages
  grep -E '^.+:[0-9]+:[0-9]+: [A-Z]+[0-9]+: .+ (\(.*\))?$' "$pylint_output_file" >"$pylint_errors"

  # Return 1 if errors were found, otherwise 0
  ! [ -s "$pylint_errors" ]
  local result=$(
    ! [ -s "$pylint_errors" ]
    echo $?
  )

  # Cleanup
  rm "$pylint_output_file" "$pylint_errors"

  return $result
}

# Function to run mypy, excluding certain files and paths, and capturing the outcome
run_mypy() {
  find "${PYTHON_SOURCE_LOCATIONS[@]}" -type f -name "*.py" \
    \! -name "Ortheus.py" \
    \! -name "*citest*.py" \
    \! -path "*/citest/*" -print0 |
    xargs -0 mypy --config-file pyproject.toml --namespace-packages --explicit-package-bases

  # Return the exit status of mypy
  return $?
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
