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


prove -r ./travisci/perl-linter/
rt1=$?

# Check that all the PODs are valid (we don't mind missing PODs at the moment)
# Note the initial "!" to negate grep's return code
! find docs modules scripts sql travisci \( -iname '*.t' -o -iname '*.pl' -o -iname '*.pm' \) -print0 | xargs -0 podchecker 2>&1 | grep -v ' pod syntax OK' | grep -v 'does not contain any pod commands'
rt2=$?

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) ]]; then
  exit 0
else
  exit 255
fi
