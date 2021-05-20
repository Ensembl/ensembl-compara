#!/usr/bin/env perl
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
        'output_results'               => $test_infile,
        'dry_run'                      => 1,
        'create_datacheck_tickets_exe' => '$ENSEMBL_ROOT_DIR/ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl',
        'division'                     => 'vertebrates',
        'test_mode'                    => 1,
    },
    [
        [
            'WARNING',
            "Command: \$ENSEMBL_ROOT_DIR/ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl $test_infile --update --division vertebrates  --dry_run",
        ],
    ]
);

standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets',
    {
        'output_results'               => $test_infile,
        'datacheck_type'               => 'critical',
        'dry_run'                      => 1,
        'create_datacheck_tickets_exe' => '$ENSEMBL_ROOT_DIR/ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl',
        'division'                     => 'vertebrates',
        'test_mode'                    => 1,

    },
    [
        [
            'WARNING',
            "Command: \$ENSEMBL_ROOT_DIR/ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl $test_infile --update --division vertebrates --label critical --dry_run",
        ],
    ]
);

done_testing();
