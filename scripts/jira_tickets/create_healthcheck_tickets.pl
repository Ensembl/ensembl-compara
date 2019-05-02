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
use Bio::EnsEMBL::Utils::Logger;
use POSIX;
use Term::ReadKey;
use Cwd 'abs_path';

use Bio::EnsEMBL::Compara::Utils::JIRA;
use Data::Dumper;

my ( $help, $release, $division, $password );
GetOptions(
    "help"         => \$help,
    "r|release=s"  => \$release,
    "d|division=s" => \$division,
    "p|password=s" => \$password,
);
my $hc_file = $ARGV[0];
my $hc_abs_path = abs_path($hc_file);

die &helptext if ( $help || !($release && $hc_file && $division) );
our $logger = Bio::EnsEMBL::Utils::Logger->new();
my $timestamp = strftime "%d-%m-%Y %H:%M:%S", localtime time;

#----------------------------------#
#        Set up parameters         #
#----------------------------------#
if ( !$password ) {
    print 'Please type your JIRA password:';

    ReadMode('noecho');    # make password invisible on terminal
    $password = ReadLine(0);
    chomp $password;
    ReadMode(0);           # restore typing visibility on terminal
    print "\n";
}

my %capitalized_divisions = (
    'grch37'        => 'GRCh37',
    'ensembl'       => 'EnsEMBL',
    'vertebrates'   => 'Vertebrates',
    'plants'        => 'Plants',
    'metazoa'       => 'Metazoa',
);
die "Division '$division' not recognised!" unless exists $capitalized_divisions{lc $division};
$division = $capitalized_divisions{lc $division};

our $parameters = {
    release    => $release,
    division   => $division,
    tickets    => { 
        fixVersion => "Release $release",
        priority   => 'Blocker',
        project    => 'ENSCOMPARASW',
        components => ['Java Healthchecks', 'Production tasks'],
    },
    user       => $ENV{USER},
    password   => $password,    
};
Bio::EnsEMBL::Compara::Utils::JIRA->validate_user_name( $parameters->{user}, $logger );

#----------------------------------#
#          Fetch HC info           #
#----------------------------------#
my $testcase_failures = parse_healthchecks($hc_file);

#----------------------------------#
#      Create JIRA tickets         #
#----------------------------------#

# create initial ticket for HC run - failures will become subtasks of this
my $blocked_ticket_key = find_handover_ticket($release, $division, $parameters, $logger);
my $hc_task_json_ticket = {
    assignee    => $parameters->{user},
    summary     => "$hc_file ($timestamp)",
    description => "Java healthcheck failures for HC run on $timestamp\nFrom file: $hc_abs_path",
    links       => [ ['Blocks', $blocked_ticket_key] ],
    labels      => [ "Testing:to delete" ],
};
my $hc_task_jira_ticket = Bio::EnsEMBL::Compara::Utils::JIRA->json_to_jira($hc_task_json_ticket, 'Task', $parameters, $logger);

# create subtask tickets for each HC failure
my @jira_subtasks;
foreach my $testcase ( keys %$testcase_failures ) {
    my $failure_subtask_json = {
        summary => $testcase,
        description => $testcase_failures->{$testcase},
        labels      => [ "Testing:to delete" ],
    };
    push(@jira_subtasks, Bio::EnsEMBL::Compara::Utils::JIRA->json_to_jira($failure_subtask_json, 'Sub-task', $parameters, $logger));
}

# POST tickets to JIRA
my $hc_task_ticket_key = Bio::EnsEMBL::Compara::Utils::JIRA->create_ticket( $hc_task_jira_ticket, $parameters, $logger );
print "Created ticket: $hc_task_ticket_key\n";
create_blocker_link( $hc_task_ticket_key, $blocked_ticket_key );
foreach my $subtask ( @jira_subtasks ) {
    $subtask->{'fields'}->{'parent'} = { 'key' => $hc_task_ticket_key };
    my $subtask_ticket_key = Bio::EnsEMBL::Compara::Utils::JIRA->create_ticket( $subtask, $parameters, $logger );
    print "\tSubtask: $subtask_ticket_key\n";
}

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
    my ($release, $division) = @_;
    
    my $this_fixversion = $parameters->{tickets}->{fixVersion};
    $this_fixversion =~ s/ /\\u0020/g;
    my $jql = sprintf('project=%s AND fixVersion=%s', $parameters->{tickets}->{project}, $this_fixversion);
    $jql .= sprintf(' and cf[11130]="%s"', $parameters->{division}) if $parameters->{division};
    $jql .= sprintf(' and summary ~ "%s"', 'Handover of release DB' );
    my $handover_ticket_response = Bio::EnsEMBL::Compara::Utils::JIRA->post_request( 
        'rest/api/latest/search',
        { "maxResults" => 1, "jql" => $jql, },
        $parameters, $logger 
    );
    my $handover_ticket = decode_json( $handover_ticket_response->content() );
    
    print "Found ticket key '" . $handover_ticket->{issues}->[0]->{key} . "'\n";
    
    return $handover_ticket->{issues}->[0]->{key};
}

sub create_blocker_link {
    my ( $blocker_key, $blockee_key ) = @_;
    
    my $block_link_content = {
        "type" => { "name" => "Blocks" },
        "inwardIssue" => { "key" => $blocker_key },
        "outwardIssue" => { "key" => $blockee_key }
    };
    
    my $issuelink_endpoint = 'rest/api/2/issueLink';
    my $response = Bio::EnsEMBL::Compara::Utils::JIRA->post_request( $issuelink_endpoint, $block_link_content, $parameters, $logger );
    print "$blocker_key now blocks $blockee_key\n";
}


sub helptext {
	my $msg = <<HELPEND;

Usage: perl create_healthcheck_tickets.pl --release <integer> --division <string> <JavaHC output file>

HELPEND
	return $msg;
}
