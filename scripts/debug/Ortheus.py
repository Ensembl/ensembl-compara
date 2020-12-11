#!/usr/bin/env python2

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

"""Script to mimic Ortheus and return the output of a previous run"""

import os
import subprocess
import sys

# Set here the expected inputs, which you can find in the Ortheus command line
species_tree = '(((((((327:0.0585842,457:0.0598399):0.0310988,(180:0.00823412,179:0.0124659):0.09194331):0.00755855,(((334:0.0638217,214:0.064933836):0.0036732,190:0.0702538):0.0105362,((((174:0.01004235,134:0.010315324):0.0109081,212:0.0204159):0.016895,213:0.0365203):0.0231325,155:0.0629363):0.016747061):0.02896091):0.00360012,108:0.1033556):0.000861311,((((((((221:0.00217461,210:0.00336539):0.00431221,150:0.00659779):0.00185473,209:0.00857453):0.00841622,60:0.0171585):0.00275526,199:0.0196199):0.0111247,(((222:0.00407792,317:0.00410208):0.00351067,(198:0.00206424,361:0.00219576):0.0052648):0.00408468,153:0.0116608):0.01847121):0.0177918,225:0.0540072):0.0276482537,206:0.07598296):0.0211581):0.0001,(((293:0.08132458,383:0.08146022):0.00503641,(((((((443:0.00217466,147:0.00243534):0.00869776,(224:0.00173498,456:0.00390502):0.00956724):0.0169365,(((342:0.00249523,337:0.00262477):0.0001,286:0.00189147):0.0031008,392:0.00583909):0.0225753):0.00548926,435:0.0321916):0.0376598,((((445:0.00277412,422:0.00333588):0.00495005,452:0.00838995):0.01316161,397:0.020255):9.06327e-06,449:0.018974):0.0433334):0.0108219,(211:0.046385437,394:0.0474265):0.028304):0.0001,407:0.0773769):0.00881201):0.00204002,(((434:0.0434658,429:0.04457849):0.01562144,(((379:0.000795536,135:0.00108446):0.000328819,372:0.000971181):9.97128e-05,285:0.00108401):0.0568382):0.00695254,(((387:0.008825,240:0.009225):0.00225289,(416:0.00238575,237:0.00274425):0.00852647):0.0378966,396:0.054702):0.0156824):0.0167101):0.0172095):0.00431128,98:0.1029919);'
species_list = "60 98 98 108 108 108 134 134 135 135 135 147 153 174 179 180 190 190 198 211 212 222 237 285 285 285 317 327 327 334 334 361 372 372 372 379 379 379 387 394 396 407 407 407 416 429 434 434 434 435 443".split()
pid = 85677

# This is where you have saved Ortheus' output from a previous run
ref_fasta_dir = '/path/to/worker_muffato_mammals_epo_with_ext_104.95260'

def read_file(filename):
    """Helper method to read a whole file"""
    with open(filename, 'r') as fh:
        return fh.read()

# Check that we are being called with the correct arguments
assert sys.argv[-4-len(species_list):-4] == species_list
assert sys.argv[-4-len(species_list)-2] == species_tree

for i in range(4, 4+len(species_list)):
    fn = sys.argv[i]
    new_file_content = read_file(fn)
    ref_file_content = read_file(os.path.join(ref_fasta_dir, os.path.basename(fn)))
    assert new_file_content == ref_file_content

# Copy some of the reference output files
subprocess.check_call(['cp', os.path.join(ref_fasta_dir, 'output.%d.mfa' % pid), sys.argv[-3]])
subprocess.check_call(['cp', os.path.join(ref_fasta_dir, 'output.score'), os.path.curdir])

# And edit the reference tree file
expected_tmpdir = os.path.dirname(sys.argv[4])
with open(os.path.join(ref_fasta_dir, 'output.%d.tree' % pid), 'r') as fh:
    tl = fh.readlines()
ref_tmpdir = os.path.dirname(tl[1].split()[0])
with open(sys.argv[-1], 'w') as fh:
    # The first line is the tree and should remain the same
    print >> fh, tl[0],
    # The second line has paths, which have to be edited
    print >> fh, tl[1].replace(ref_tmpdir, expected_tmpdir),
