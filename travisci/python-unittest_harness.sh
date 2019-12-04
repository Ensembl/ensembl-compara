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

# Check that all the Python files can be compiled
if [ "$TEST_COMPILATION" = 'true' ]
then
  find "${PYTHON_SOURCE_LOCATIONS[@]}" -name '*.py' -print0 | xargs -0 travisci/compile.py
  rt1=$?
else
  rt1=0
fi

exit $rt1
