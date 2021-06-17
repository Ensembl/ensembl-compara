#!/usr/bin/env perl

=head1 LICENSE
See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=item B<-label> <label>

Optional. Extra label(s) to add to every ticket. Can take several values.

=item B<-update>

Optional. Update the description of the JIRA tickets that already exist (same
summary, division and release) and reopen them (removing the previous assignee).
By default, don't update them.


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

my ( $release, $division, @labels, $update, $dry_run, $help );
$update  = 0;
$dry_run = 0;
$help    = 0;
GetOptions(
    "d|division=s"    => \$division,
    "r|release=s"     => \$release,
    "label=s"         => \@labels,
    "update"          => \$update,
    'dry_run|dry-run' => \$dry_run,
    "h|help"          => \$help,
);
pod2usage(1) if $help;
pod2usage(1) unless @ARGV;
my $dc_file = $ARGV[0];
die "Cannot find $dc_file - file does not exist" unless -e $dc_file;
# Get file absolute path
my $dc_abs_path = abs_path($dc_file);
# Get a new Utils::JIRA object to create the tickets for the given division and
# release
my $jira_adaptor = Bio::EnsEMBL::Compara::Utils::JIRA->new(-DIVISION => $division, -RELEASE => $release);
# Parse Datacheck information from input TAP file
my $testcase_failures = parse_datachecks($dc_file);
unless ( %$testcase_failures ) {
    print "No failed DCs found in $dc_file\n";
    exit;
}
# Create a task ticket for each datacheck subtest failure
my $merge_ticket_key = find_labeled_ticket($jira_adaptor, 'Merge_anchor');
my @json_subtasks;
foreach my $testcase ( keys %$testcase_failures ) {
    my $failure_subtask_json = {
        summary     => "Datacheck $testcase failed",
        description => "*TAP file*: $dc_abs_path\n" . $testcase_failures->{$testcase},
        parent      => $merge_ticket_key,
    };
    push(@json_subtasks, $failure_subtask_json);
}
my $components = ['Datachecks', 'Production tasks'];
my $categories = ['Bug::Internal', 'Production::Tasks'];
# Create all JIRA tickets
my $dc_task_keys = $jira_adaptor->create_tickets(
    -JSON_OBJ           => \@json_subtasks,
    -DEFAULT_ISSUE_TYPE => 'Sub-task',
    -DEFAULT_PRIORITY   => 'Blocker',
    -EXTRA_COMPONENTS   => $components,
    -EXTRA_CATEGORIES   => $categories,
    -EXTRA_LABELS       => \@labels,
    -UPDATE             => $update,
    -DRY_RUN            => $dry_run
);

# Create a blocker issue link between the newly created datacheck ticket and the
# handover ticket if it doesn't already exist
my $blocked_ticket_key = find_labeled_ticket($jira_adaptor, 'Handover_anchor');
$jira_adaptor->link_tickets('Blocks', $dc_task_keys->[0], $blocked_ticket_key, $dry_run);


sub parse_datachecks {
    my $dc_file = shift;
    open(my $dc_fh, '<', $dc_file) or die "Cannot open $dc_file for reading";
    my ($test, $testcase, $dc_failures);
    my $capture_failure = 0;
    while (my $line = <$dc_fh>) {
        # Remove any spaces/tabs at the end of the line
        $line =~ s/\s+$//;
        next unless $line;

        # Get the main test name
        if ($line =~ /^# Subtest: (\w+)$/) {
            $test = $1;
            next;
        }

        # Save all the information provided about the failure
        if ( $line =~ /^[ ]{8}(not ok .+)$/ ) {
            $capture_failure = 1;
            push @{ $dc_failures->{$test} }, $1;
        } elsif ( $line =~ /^[ ]{8}(#.+)$/) {
            push @{ $dc_failures->{$test} }, $1 if $capture_failure;
        } else {
            $capture_failure = 0;
        }
    }
    close($dc_fh);

    # Wrap failure details in code blocks
    foreach my $subtest ( keys %$dc_failures ) {
        $dc_failures->{$subtest} = sprintf("%s\n%s\n%s\n", (
            "{code:title=Subtest $subtest}",
            join("\n", @{ $dc_failures->{$subtest} }),
            "{code}"
        ));
    }
    return $dc_failures;
}

sub find_labeled_ticket {
    my ($jira_adaptor, $label) = @_;

    my $jql = "labels=$label";
    my $labeled_ticket = $jira_adaptor->fetch_tickets($jql);

    # Check that we have actually found the ticket (and only one)
    die "Cannot find any ticket with the label '$label'" if (! $labeled_ticket->{total});
    die "Found more than one ticket with the label '$label'" if ($labeled_ticket->{total} > 1);
    print "Found ticket key '" . $labeled_ticket->{issues}->[0]->{key} . "'\n";

    return $labeled_ticket->{issues}->[0]->{key};
}
