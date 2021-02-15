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

=head2 SUMMARY

This script parses the output from Ensembl's Java healthchecks and creates 
JIRA tickets for each failure

=cut


use warnings;
use strict;

use Getopt::Long;
use POSIX;
use Cwd 'abs_path';
use File::Basename;

use Bio::EnsEMBL::Compara::Utils::JIRA;

my ( $help, $release, $division, $dry_run );
$dry_run = 0;
GetOptions(
    "help"         => \$help,
    "r|release=s"  => \$release,
    "d|division=s" => \$division,
    'dry_run|dry-run!' => \$dry_run,
);
die &helptext if $help;
my $hc_file = $ARGV[0];
die "Cannot find $hc_file - file does not exist" unless -e $hc_file;
my $hc_abs_path = abs_path($hc_file);
my $hc_basename = fileparse($hc_abs_path,('.txt', '.out'));

die &helptext if ( !($release && $hc_file && $division) );
my $timestamp = strftime "%d-%m-%Y %H:%M:%S", localtime time;

# Get a new Utils::JIRA object to create the tickets for the given division and
# release
my $jira_adaptor = new Bio::EnsEMBL::Compara::Utils::JIRA(-DIVISION => $division, -RELEASE => $release);

#----------------------------------#
#          Fetch HC info           #
#----------------------------------#
my $testcase_failures = parse_healthchecks($hc_file, $timestamp);

#----------------------------------#
#      Create JIRA tickets         #
#----------------------------------#

# create initial ticket for HC run - failures will become subtasks of this
my $blocked_ticket_key = find_handover_ticket($jira_adaptor);
my $hc_task_json_ticket = [{
    assignee    => $jira_adaptor->{_user},
    summary     => "$hc_basename ($timestamp)",
    description => "Java healthcheck failures for HC run on $timestamp\nFrom file: $hc_abs_path",
}];

# create subtask tickets for each HC failure
my @json_subtasks;
foreach my $testcase ( keys %$testcase_failures ) {
    my $failure_subtask_json = {
        summary => $testcase,
        description => $testcase_failures->{$testcase},
    };
    push(@json_subtasks, $failure_subtask_json);
}
# Add subtasks to the initial ticket
$hc_task_json_ticket->[0]->{subtasks} = \@json_subtasks;
my $components = ['Datachecks', 'Production tasks'];
my $categories = ['Bug::Internal', 'Production::Tasks'];
# Create all JIRA tickets
my $hc_task_keys = $jira_adaptor->create_tickets(
    -JSON_OBJ         => $hc_task_json_ticket,
    -DEFAULT_PRIORITY => 'Blocker',
    -EXTRA_COMPONENTS => $components,
    -EXTRA_CATEGORIES => $categories,
    -DRY_RUN          => $dry_run
);
# Create a blocker issue link between the newly created HC ticket and the
# handover ticket
$jira_adaptor->link_tickets('Blocks', $hc_task_keys->[0], $blocked_ticket_key, $dry_run);

sub parse_healthchecks {
    my ($hc_file, $timestamp) = @_;
    open(my $hc_fh, '<', $hc_file) or die "Cannot open $hc_file for reading";
    my ($results, $testcase, $hc_failures);
    while ( my $line = <$hc_fh> ) {
        $results = 1 if ($line =~ /RESULTS BY TEST CASE/);
        next unless $results;
        $line =~ s/\s+$//;
        
        my $header = 0;
        if ($line =~ /org\.ensembl\.healthcheck\.(testcase|testgroup)\.(\S+)/) {
            $testcase = "$2 ($timestamp)";
            $header = 1;
        }
        next unless $testcase;
        if ( $header ) {
            $hc_failures->{$testcase} = "{code:title=$line}\n";
        } else {
            $hc_failures->{$testcase} .= "$line\n";
        }
    }
    close($hc_fh);
    
    foreach my $testcase ( keys %$hc_failures ) {
        $hc_failures->{$testcase} .= "{code}\n";
    }
    return $hc_failures;
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

sub helptext {
	my $msg = <<HELPEND;

Usage: perl create_healthcheck_tickets.pl --release <integer> --division <string> [--dry_run] <JavaHC output file>

HELPEND
	return $msg;
}
