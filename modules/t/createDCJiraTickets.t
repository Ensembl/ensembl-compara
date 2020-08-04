#!/usr/bin/env perl
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

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

BEGIN {
    use Test::Most;
}

use_ok('Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets');

use Cwd 'abs_path';
my $test_infile = abs_path($0);
$test_infile    =~ s!CreateDCJiraTickets\.t!dc_tap_files/datacheck.tap!;

standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets',
    {
        'output_results' => $test_infile,
    },
    [
        [
            'WARNING',
            "Command: \$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl $test_infile --update",
        ],
    ]
);

done_testing();
