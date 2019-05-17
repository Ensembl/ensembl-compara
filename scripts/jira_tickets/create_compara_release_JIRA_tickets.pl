#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

#example : perl create_compara_release_JIRA_tickets.pl -tickets ~/Jira_recurrent_tickets.txt -c ~/AutomaticJiraTickets.conf -release 89

use strict;
use warnings;
use diagnostics;
use autodie;
use feature qw(say);

use FindBin;
use Getopt::Long;
use Config::Tiny;

use JSON;
use HTTP::Request;
use LWP::UserAgent;
use Term::ReadKey;

use Bio::EnsEMBL::Utils::Logger;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::IO qw (slurp);
use Bio::EnsEMBL::Compara::Utils::JIRA;

use Data::Dumper;

main();

sub main {

    # -----------------
    # initialize logger
    # -----------------
    my $logger = Bio::EnsEMBL::Utils::Logger->new();

    # $logger->init_log();

    # ----------------------------
    # read command line parameters
    # ----------------------------
    my ( $user, $relco, $release, $password, $help, $tickets_json, $config, $division );

    GetOptions(
        'relco=s'    => \$relco,
        'release=i'  => \$release,
        'password|p=s' => \$password,
        'division|d=s' => \$division,
        'tickets=s'  => \$tickets_json,
        'config|c=s' => \$config,
        'help|h'     => \$help,
    );

    # ------------
    # display help
    # ------------
    if ($help) {
        usage();
    }

    # ---------------------------------
    # deal with command line parameters
    # ---------------------------------
    ( $user, $relco, $release, $password, $tickets_json, $config, $division )
        = set_parameters( $relco, $release, $password, $tickets_json, $config, $division,
        $logger );

    # ---------------------------
    # read config file parameters
    # ---------------------------
    my $parameters = Config::Tiny->read($config);

    # check_dates($parameters);
    
    # integrate command line parameters to parameters object
    $parameters->{user}     = $user;
    $parameters->{relco}    = $relco;
    $parameters->{password} = $password;
    $parameters->{release}  = $release;
    $parameters->{tickets}->{fixVersion} = "Release $release";
    $parameters->{division} = $division if ($division ne 'relco');

    # ------------------
    # parse tickets file
    # ------------------
    my $tickets = decode_json slurp($tickets_json) or die "Could not open file '$tickets_json' $!";

    # ----------------------
    # convert to JIRA format
    # ----------------------
    foreach my $ticket (@$tickets) {
        $ticket->{'jira'} = Bio::EnsEMBL::Compara::Utils::JIRA->json_to_jira($ticket, 'Task', $parameters, $logger);
        if ($ticket->{'subtasks'}) {
            foreach my $subtask ( @{$ticket->{'subtasks'}} ) {
                $subtask->{'jira'} = Bio::EnsEMBL::Compara::Utils::JIRA->json_to_jira($subtask, 'Sub-task', $parameters, $logger);
            }
        }
    }
    $logger->info('Tickets to submit: '. Dumper($tickets));

    # --------------------------------
    # get existing tickets for current
    # release from the JIRA server
    # --------------------------------
    my $fixVersion = $parameters->{tickets}->{fixVersion};
    $fixVersion =~ s/ /\\u0020/g;
    my $jql = sprintf('project=%s AND fixVersion=%s', $parameters->{tickets}->{project}, $fixVersion);
    $jql .= sprintf(' and cf[11130]="%s"', $parameters->{division}) if $parameters->{division};
    my $existing_tickets_response = Bio::EnsEMBL::Compara::Utils::JIRA->post_request( 
        'rest/api/latest/search',
        { "maxResults" => 300, "jql" => $jql, },
        $parameters, $logger 
    );
    my $existing_tickets
        = decode_json( $existing_tickets_response->content() );
    $parameters->{existing_tickets} = {map {(($parameters->{division} // '') . '--' . $_->{fields}->{summary}) => $_->{key}} @{$existing_tickets->{issues}}};
    $logger->info('Existing tickets: ' . Dumper($parameters->{existing_tickets}));

    # -----------------------
    # create new JIRA tickets
    # -----------------------
    for my $ticket ( @{$tickets} ) {
        my $ticket_key = Bio::EnsEMBL::Compara::Utils::JIRA->create_ticket( $ticket->{'jira'}, $parameters, $logger );
        if ($ticket->{'subtasks'}) {
            foreach my $subtask (@{$ticket->{'subtasks'}}) {
                $subtask->{'jira'}->{'fields'}->{'parent'} = { 'key'  => $ticket_key };
                my $subtask_key = Bio::EnsEMBL::Compara::Utils::JIRA->create_ticket( $subtask->{'jira'}, $parameters, $logger );
            }
        }
    }
}

=head2 set_parameters

  Arg[1]      : String $relco - a Regulation team member name or JIRA username
  Arg[2]      : Integer $release - the EnsEMBL release version
  Arg[3]      : String $password - user's JIRA password
  Arg[4]      : String $tickets_json - path to the json file that holds the input
  Arg[5]      : String $config - path to the config file holding handover dates
  Arg[6]      : String $division
  Arg[7]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Description : Makes sure that the parameters provided through the command line
                are valid and assigns default values to the ones which where not 
                supplied
  Return type : Listref
  Exceptions  : none

=cut

sub set_parameters {
    my ( $relco, $release, $password, $tickets_json, $config, $division, $logger ) = @_;

    $relco = $ENV{'USER'} if !$relco;
    $relco = Bio::EnsEMBL::Compara::Utils::JIRA->validate_user_name( $relco, $logger );

    my $user = Bio::EnsEMBL::Compara::Utils::JIRA->validate_user_name( $ENV{'USER'}, $logger );

    $release = Bio::EnsEMBL::ApiVersion->software_version() if !$release;

    my %capitalized_divisions = (
        'grch37'        => 'GRCh37',
        'ensembl'       => 'Ensembl',
        'vertebrates'   => 'Vertebrates',
        'plants'        => 'Plants',
        'metazoa'       => 'Metazoa',
    );
    $division ||= '';
    if (!$division) {
        warn "No division given, will load the division-agnostic 'relco' JSON file";

    } elsif (!$capitalized_divisions{lc $division}) {
        $logger->error("Division '$division' not recognized", 0, 0);
    }
    $division = $division ? $capitalized_divisions{lc $division} : 'relco';

    $tickets_json = $FindBin::Bin . '/jira_recurrent_tickets.' . lc $division . '.json'
        if !$tickets_json;

    if ( !-e $tickets_json ) {
        $logger->error(
            'Tickets file '
                . $tickets_json
                . ' not found! Please specify one using the -tickets option!',
            0, 0
        );
    }

    $config = $FindBin::Bin . '/jira.conf' if !$config;

    if ( !-e $config ) {
        $logger->error(
            'Config file '
                . $config
                . ' not found! Please specify one using the -config option!',
            0, 0
        );
    }

    printf( "\trelco: %s\n\trelease: %i\n\tdivision: %s\n\ttickets: %s\n\tconfig: %s\n\tJIRA user: %s\n",
        $relco, $release, $division, $tickets_json, $config, $user );
    print "Are the above parameters correct? (y,N) : ";
    my $response = readline();
    chomp $response;
    if ( $response ne 'y' ) {
        $logger->error(
            'Aborted by user. Please rerun with correct parameters.',
            0, 0 );
    }

    if ( !$password ) {
        print 'Please type your JIRA password:';

        ReadMode('noecho');    # make password invisible on terminal
        $password = ReadLine(0);
        chomp $password;
        ReadMode(0);           # restore typing visibility on terminal
        print "\n";
    }

    return ( $user, $relco, $release, $password, $tickets_json, $config, $division );
}


sub usage {
    print <<EOF;
=head1
create_JIRA_tickets.pl -relco <string> -password <string> -release <integer> -tickets <file> -config <file> 

-relco               JIRA username. Optional, will be inferred from current system user if not supplied.
-password | -p       JIRA password. Will need to be typed in standard input if not supplied.
-release             EnsEMBL Release. Optional, will be inferred from EnsEMBL API if not supplied.
-tickets             File that holds the input data for creating the JIRA tickets in tab separated format.
                     If not supplied, the script is looking for the default one 'jira_recurrent_tickets.json'
                     in the same directory as the executable.
-config              Configuration parameters file, currently holds the handover deadlines, may be expanded
                     in the future. If not supplied, the script is looking for the default one 'jira.conf'
                     in the same directory as the executable.
-help | -h           Prints this help text.

Reads the -tickets input file and creates JIRA tickets
EOF
    exit 0;
}
