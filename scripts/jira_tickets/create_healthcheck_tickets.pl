#!/usr/bin/env perl

=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

use JSON;
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
my $hc_file = $ARGV[0];
die "Cannot find $hc_file - file does not exist" unless -e $hc_file;
my $hc_abs_path = abs_path($hc_file);
my $hc_basename = fileparse($hc_abs_path,('.txt', '.out'));

die &helptext if ( $help || !($release && $hc_file && $division) );
my $timestamp = strftime "%d-%m-%Y %H:%M:%S", localtime time;

# Get a new Utils::JIRA object to create the tickets for the given division and
# release
my $jira_adaptor = new Bio::EnsEMBL::Compara::Utils::JIRA(-DIVISION => $division, -RELEASE => $release);

#----------------------------------#
#          Fetch HC info           #
#----------------------------------#
my $testcase_failures = parse_healthchecks($hc_file);

#----------------------------------#
#      Create JIRA tickets         #
#----------------------------------#

# create initial ticket for HC run - failures will become subtasks of this
my $blocked_ticket_key = find_handover_ticket($jira_adaptor);
my $hc_task_json_ticket = [{
    assignee    => $jira_adaptor->{_user},
    summary     => "$hc_basename ($timestamp)",
    description => "Java healthcheck failures for HC run on $timestamp\nFrom file: $hc_abs_path",
    links       => [ ['Blocks', $blocked_ticket_key] ],
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
my $components = ['Java Healthchecks', 'Production tasks'];
# Create all JIRA tickets
my $hc_task_keys = $jira_adaptor->create_tickets(
    -JSON_INPUT => encode_json($hc_task_json_ticket), -PRIORITY => 'Blocker', -COMPONENTS => $components,
    -DRY_RUN => $dry_run
);
# Create a blocker issue link between the newly created HC ticket and the
# handover ticket
$jira_adaptor->link_tickets('Blocks', $hc_task_keys->[0], $blocked_ticket_key, $dry_run);

sub parse_healthchecks {
    my $hc_file = shift;
    open(HC, '<', $hc_file) or die "Cannot open $hc_file for reading";
    my ($results, $testcase, $hc_failures);
    while ( my $line = <HC> ) {
        $results = 1 if ($line =~ /RESULTS BY TEST CASE/);
        next unless $results;
        $line =~ s/\s+$//;
        
        my $header = 0;
        if ($line =~ /org\.ensembl\.healthcheck\.testcase\.(\S+)/) {
            $testcase = $1;
            $header = 1;
        }
        next unless $testcase;
        if ( $header ) {
            $hc_failures->{$testcase} = "{panel:title=$line}\n";
        } else {
            $hc_failures->{$testcase} .= "$line\n";
        }
    }
    
    foreach my $testcase ( keys %$hc_failures ) {
        $hc_failures->{$testcase} .= "{panel}\n";
    }
    return $hc_failures;
}

sub find_handover_ticket {
    my ($jira_adaptor) = @_;
    
    my $fixVersion = 'Release\u0020' . $jira_adaptor->{_release};
    my $jql = sprintf('project=%s AND fixVersion=%s', $jira_adaptor->{_project}, $fixVersion);
    $jql .= sprintf(' and cf[11130]="%s"', $jira_adaptor->{_division}) if $jira_adaptor->{_division};
    $jql .= sprintf(' and summary ~ "%s"', 'Handover of release DB' );
    my $handover_ticket = $jira_adaptor->fetch_tickets($jql);
    
    print "Found ticket key '" . $handover_ticket->{issues}->[0]->{key} . "'\n";
    
    return $handover_ticket->{issues}->[0]->{key};
}

sub helptext {
	my $msg = <<HELPEND;

Usage: perl create_healthcheck_tickets.pl --release <integer> --division <string> <JavaHC output file>

HELPEND
	return $msg;
}
