
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the
# EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This script run the CITest tests

It is design to run the test fir one pipeline per call.
"""

import argparse
from ensembl.compara.citest.citest import CITest

parser = argparse.ArgumentParser()
parser.add_argument("--url", type=str,
                    help="URL to conect to the MySQL database")
parser.add_argument("--url_ref", type=str,
                    help="URL to conect to the reference MySQL database")
parser.add_argument("--test", type=str, help="JSON test file", required=True)
parser.add_argument("--user", type=str, help="db conection user id")
parser.add_argument("--password", type=str, help="db connection password")
parser.add_argument("--server", type=str, help="Mysql server address")
parser.add_argument("--outdir", type=str, help="out directory where to write the file",
                    default="./")
parser.add_argument("--print", type=int,
                    help="tag for printing the output to the screen. '1' on '0' ", default=0)
args = parser.parse_args()

citest = CITest()
citest.init_citest(args.url_ref, args.url, args.test, args.outdir)
citest.run_citest()
if args.print == 1:
    citest.print_citest_results()
citest.write_citest_results_json()
