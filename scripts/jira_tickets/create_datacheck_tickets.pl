#!/usr/bin/env perl

=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=cut

=head2 DESCRIPTION

This script parses the output from Ensembl's Datachecks and creates JIRA 
tickets for each failure.

=head1 SYNOPSIS

perl create_datacheck_tickets.pl [options] <datacheck_TAP_file>

=head1 OPTIONS

=over

=item B<-d[ivision]> <division>

Optional. Compara division. If not given, uses environment variable
$COMPARA_DIV as default.

=item B<-r[elease]> <release>

Optional. Ensembl release version. If not given, uses environment variable 
$CURR_ENSEMBL_RELEASE as default.

=item B<-dry_run>, B<-dry-run>

In dry-run mode, the JIRA tickets will not be submitted to the JIRA 
server. By default, dry-run mode is off.

=item B<-h[elp]>

Print usage information.

=back

=cut


use warnings;
use strict;

use Cwd 'abs_path';
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use POSIX;

use Bio::EnsEMBL::Compara::Utils::JIRA;

my ( $release, $division, $dry_run, $help );
$dry_run = 0;
$help    = 0;
GetOptions(
    "d|division=s"    => \$division,
    "r|release=s"     => \$release,
    'dry_run|dry-run' => \$dry_run,
    "h|help"          => \$help,
);
pod2usage(1) if $help;
my $dc_file = $ARGV[0];
die "Cannot find $dc_file - file does not exist" unless -e $dc_file;
# Get file absolute path and basename
my $dc_abs_path = abs_path($dc_file);
my $dc_basename = fileparse($dc_abs_path, qr{\.[a-zA-Z0-9_]+$});
# Get timestamp that will be included in the summary of each JIRA ticket
my $timestamp = strftime("%d-%m-%Y %H:%M:%S", localtime time);
# Get a new Utils::JIRA object to create the tickets for the given division and
# release
my $jira_adaptor = Bio::EnsEMBL::Compara::Utils::JIRA->new(-DIVISION => $division, -RELEASE => $release);
# Parse Datacheck information from input TAP file
my $testcase_failures = parse_datachecks($dc_file, $timestamp);
# Create initial ticket for datacheck run - failures will become subtasks of this
my $blocked_ticket_key = find_handover_ticket($jira_adaptor);
my $dc_task_json_ticket = [{
    assignee    => $jira_adaptor->{_user},
    summary     => "$dc_basename ($timestamp)",
    description => "Datacheck failures raised on $timestamp\nFrom file: $dc_abs_path",
}];
# Create subtask tickets for each datacheck failure
my @json_subtasks;
foreach my $testcase ( keys %$testcase_failures ) {
    my $failure_subtask_json = {
        summary     => $testcase,
        description => $testcase_failures->{$testcase},
    };
    push(@json_subtasks, $failure_subtask_json);
}
# Add subtasks to the initial ticket
$dc_task_json_ticket->[0]->{subtasks} = \@json_subtasks;
my $components = ['Java Healthchecks', 'Production tasks'];
# Create all JIRA tickets
my $dc_task_keys = $jira_adaptor->create_tickets(
    -JSON_OBJ         => $dc_task_json_ticket,
    -DEFAULT_PRIORITY => 'Blocker',
    -EXTRA_COMPONENTS => $components,
    -DRY_RUN          => $dry_run
);
# Create a blocker issue link between the newly created datacheck ticket and the
# handover ticket
$jira_adaptor->link_tickets('Blocks', $dc_task_keys->[0], $blocked_ticket_key, $dry_run);

sub parse_datachecks {
    my ($dc_file, $timestamp) = @_;
    open(my $dc_fh, '<', $dc_file) or die "Cannot open $dc_file for reading";
    my ($test, $testcase, $dc_failures);
    while (my $line = <$dc_fh>) {
        # Remove any spaces/tabs at the end of the line
        $line =~ s/\s+$//;
        # Get the main test name
        if ($line =~ /^# Subtest: (\w+)$/) {
            $test = $1;
            next;
        }
        # Get the test case number and summary that has failed
        if ($line =~ /^[ ]{8}not ok (\d+) - (.+)$/) {
            $testcase = "${test} subtest $1 ($timestamp)";
            $dc_failures->{$testcase} = "{code:title=$2}\n";
            next;
        }
        # Save all the information provided about the failure
        if ($line =~ /^[ ]{8}#   (.+)$/) {
            $dc_failures->{$testcase} .= "$1\n";
        }
    }
    close($dc_fh);
    # Close all code blocks created
    foreach my $testcase ( keys %$dc_failures ) {
        $dc_failures->{$testcase} .= "{code}\n";
    }
    return $dc_failures;
}

sub find_handover_ticket {
    my ($jira_adaptor) = @_;

    my $jql = 'labels=Handover_anchor';
    my $handover_ticket = $jira_adaptor->fetch_tickets($jql);

    # Check that we have actually found the ticket (and only one)
    die 'Cannot find any ticket with the label "Handover_anchor"' if (! $handover_ticket->{total});
    die 'Found more than one ticket with the label "Handover_anchor"' if ($handover_ticket->{total} > 1);
    print "Found ticket key '" . $handover_ticket->{issues}->[0]->{key} . "'\n";

    return $handover_ticket->{issues}->[0]->{key};
}
