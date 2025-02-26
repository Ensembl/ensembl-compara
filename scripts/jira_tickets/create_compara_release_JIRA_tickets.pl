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

use FindBin;
use Getopt::Long;

use Bio::EnsEMBL::Compara::Utils::JIRA;

# Epic JIRA Ticket ID for Production taks
use constant EPIC_TICKET_ID => 'ENSCOMPARASW-3572';

main();

sub main {
    # ----------------------------
    # read command line parameters
    # ----------------------------
    my ( $user, $relco, $release, $help, $tickets_json, $division, $dry_run, $csv );
    # Set default values
    $division = '';
    $dry_run = 0;

    GetOptions(
        'relco=s'    => \$relco,
        'release=i'  => \$release,
        'division|d=s' => \$division,
        'tickets=s'  => \$tickets_json,
        'dry_run|dry-run!' => \$dry_run,
        'csv=s'      => \$csv,
        'help|h'     => \$help,
    );

    # ------------
    # display help
    # ------------
    if ($help) {
        usage();
    }

    # Get a new Utils::JIRA object to create the tickets for the given relco,
    # division and release
    my $jira_adaptor = new Bio::EnsEMBL::Compara::Utils::JIRA(
        -RELCO    => $relco,
        -DIVISION => $division,
        -RELEASE  => $release,
        -CSV      => $csv,
    );
    # If no division is given, set it to 'relco'
    $division = $division ? lc $division : 'relco';

    # Check if the introduced/default tickets JSON file exists
    $tickets_json = $ENV{'ENSEMBL_ROOT_DIR'} . '/ensembl-compara/conf/' . $division . '/jira_recurrent_tickets.json'
        if $ENV{'ENSEMBL_ROOT_DIR'} && !$tickets_json;
    die "Tickets file '$tickets_json' not found! Please, specify one using -tickets option."
        if ( !-e $tickets_json );

    # Ask the user to verify the parameters that are going to be used to create
    # the tickets
    printf( "\trelco: %s\n\trelease: %i\n\tdivision: %s\n\ttickets: %s\n\tJIRA user: %s\n",
        $jira_adaptor->{_relco}, $jira_adaptor->{_release}, $division, $tickets_json, $jira_adaptor->{_user}
    );
    print "Are the above parameters correct? (y,N) : ";
    my $response = readline();
    chomp $response;
    die 'Aborted by user. Please rerun with correct parameters.' if ( $response ne 'y' );

    # Create JIRA tickets
    my $num_tickets;
    if ($csv) {
        my $issue_ids = $jira_adaptor->create_ticket_csv(
            -JSON_FILE        => $tickets_json,
            -DEFAULT_PRIORITY => 'Blocker',
            -EPIC_LINK        => EPIC_TICKET_ID(),
            -DRY_RUN          => $dry_run,
            -CSV_FILE         => $csv,
        );
        $num_tickets = scalar(@$issue_ids);
    } else {
        my $subtask_keys= $jira_adaptor->create_tickets(
            -JSON_FILE        => $tickets_json,
            -DEFAULT_PRIORITY => 'Blocker',
            -EPIC_LINK        => EPIC_TICKET_ID(),
            -DRY_RUN          => $dry_run,
        );
        $num_tickets = scalar(@$subtask_keys);
    }
    printf("Created %d top-level tickets.\n", $num_tickets);
}


sub usage {
    print <<EOF;
=head1
create_compara_release_JIRA_tickets.pl -relco <string> -release <integer> -division <division> -tickets <file>

-relco               JIRA username. Optional, will be inferred from current system user if not supplied.
-release             EnsEMBL Release. Optional, will be obtained from environment variable
                     \$CURR_ENSEMBL_RELEASE if not supplied.
-division | -d       Compara division. Optional, will be obtained from environment variable \$COMPARA_DIV
                     if not supplied.
-tickets             File that holds the input data for creating the JIRA tickets in JSON format. Optional,
                     the script will look for 'jira_recurrent_tickets.json' in \$ENSEMBL_ROOT_DIR/ensembl-compara/conf/<division>
                     if not supplied (assuming \$ENSEMBL_ROOT_DIR is set).
-dry_run | -dry-run  In dry-run mode, the JIRA tickets will not be submitted to the JIRA server. Optional,
                     dry-run mode is off by default.
-csv                 Instead of creating JIRA tickets, output their data to a CSV file which can be imported to JIRA.
-help | -h           Prints this help text.

Reads the -tickets input file and creates JIRA tickets
EOF
    exit 0;
}
