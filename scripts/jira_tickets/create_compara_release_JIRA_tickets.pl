#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
    my ( $user, $relco, $release, $password, $help, $tickets_json, $ticket_mapping_file, $config, $division );

    GetOptions(
        'relco=s'    => \$relco,
        'release=i'  => \$release,
        'password|p=s' => \$password,
        'division|d=s' => \$division,
        'tickets=s'  => \$tickets_json,
        'mapping=s'  => \$ticket_mapping_file,
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
        json_to_jira($ticket, 'Task', $parameters, $logger);
        if ($ticket->{'subtasks'}) {
            json_to_jira($_, 'Sub-task', $parameters, $logger) for @{$ticket->{'subtasks'}};
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
    my $existing_tickets_response
        = post_request( 'rest/api/latest/search',
        { "maxResults" => 300, "jql" => $jql, },
        $parameters, $logger );
    my $existing_tickets
        = decode_json( $existing_tickets_response->content() );
    $parameters->{existing_tickets} = {map {(($parameters->{division} // '') . '--' . $_->{fields}->{summary}) => $_->{key}} @{$existing_tickets->{issues}}};
    $logger->info('Existing tickets: ' . Dumper($parameters->{existing_tickets}));

    # -----------------------
    # create new JIRA tickets
    # -----------------------
    my $mapping_str = '';
    for my $ticket ( @{$tickets} ) {
        my $ticket_key = create_ticket( $ticket, $parameters, $logger );
        $mapping_str .= $ticket->{ticket_map_name} . "\t" . $ticket_key . "\n" if $ticket->{ticket_map_name};
        if ($ticket->{'subtasks'}) {
            foreach my $subtask (@{$ticket->{'subtasks'}}) {
                $subtask->{'jira'}->{'parent'} = { 'key'  => $ticket_key };
                my $subtask_key = create_ticket( $subtask, $parameters, $logger );
                $mapping_str .= $subtask->{ticket_map_name} . "\t" . $subtask_key . "\n" if $subtask->{ticket_map_name};
            }
        }
    }

    # once we're sure all tickets have been created successfully, write the mapping file
    $ticket_mapping_file = 'jira_ticket_mapping.tsv' unless $ticket_mapping_file;
    open( my $map_fh, '>', $ticket_mapping_file );
    print $map_fh $mapping_str;
    close $map_fh;
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
    $relco = validate_user_name( $relco, $logger );

    my $user = validate_user_name( $ENV{'USER'}, $logger );

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

=head2 validate_user_name

  Arg[1]      : String $user - a Regulation team member name or JIRA username
  Arg[2]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Example     : my $valid_user = validate_user_name($user, $logger)
  Description : Checks if the provided user name is valid, returns valid JIRA
                username
  Return type : String
  Exceptions  : none

=cut

sub validate_user_name {
    my ( $user, $logger ) = @_;

    my %valid_user_names = (
        'aj'   => 'waakanni',
	'wasiu' => 'waakanni',
	'waakanni' => 'waakanni',
        'carla' => 'carlac',
        'carlac'    => 'carlac',
        'muffato'    => 'muffato',
        'matthieu'  => 'muffato',
        'mateus'  => 'mateus'
    );

    if ( exists $valid_user_names{$user} ) {
        return $valid_user_names{$user};
    }
    else {
        my $valid_names = join( "\n", sort keys %valid_user_names );
        $logger->error(
            "User name $user not valid! Here is a list of valid names:\n"
                . $valid_names,
            0, 0
        );
    }
}


sub json_to_jira {
    my ($json_hash, $issuetype, $parameters, $logger) = @_;

    # We can define one or many components
    my @components;
    if ($json_hash->{'component'}) {
        push @components, { 'name' => $json_hash->{'component'} };
    } else {
        push @components, { 'name' => $_ } for @{$json_hash->{'components'}};
    }

    my %ticket = (
        'project'     => { 'key'  => $json_hash->{'project'} || $parameters->{'tickets'}->{'project'} },
        'issuetype'   => { 'name' => $issuetype },
        'summary'     => replace_placeholders( $json_hash->{'summary'}, $parameters ),
        'priority'    => { 'name' => $json_hash->{'priority'} || $parameters->{'tickets'}->{'priority'} },
        'fixVersions' => [
            { 'name' => $parameters->{'tickets'}->{'fixVersion'} },
        ],
        'components'  => \@components,
        'description' => replace_placeholders( $json_hash->{'description'}, $parameters ),
    );
    if ($parameters->{'division'}) {
        $ticket{'customfield_11130'} = { 'value' => $parameters->{'division'} };
    }

    if ($json_hash->{'assignee'}) {
        $ticket{'assignee'} = { 'name' => validate_user_name( replace_placeholders( $json_hash->{'assignee'}, $parameters), $logger ) };
    }

    $json_hash->{'jira'} = \%ticket;
    return \%ticket;
}

=head2 replace_placeholders

  Arg[1]      : String $line - One line from the json input file
  Arg[2]      : Hashref $parameters - parameters from command line and config
  Example     : $line = replace_placeholders( $line, $parameters );
  Description : Replaces the placeholder tags with valid values and returns a
                a new string
  Return type : String
  Exceptions  : none

=cut

sub replace_placeholders {
    my ( $line, $parameters ) = @_;

    return '' unless $line;

    $line =~ s/<RelCo>/$parameters->{relco}/g;
    $line =~ s/<version>/$parameters->{release}/g;
    if ($parameters->{division}) {
        $line =~ s/<Division>/$parameters->{division}/g;
        my $lcdiv = lc $parameters->{division};
        $line =~ s/<division>/$lcdiv/g;
    }

    return $line;
}


=head2 create_ticket

  Arg[1]      : Hashref $line - Holds the ticket data
  Arg[2]      : Hashref $parameters - parameters from command line and config
  Arg[3]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Example     : my $ticket_key = create_ticket( $ticket, $parameters, $logger );
  Description : Submits a post request to the JIRA server that creates a new
                ticket. Returns the key of the created ticket
  Return type : String
  Exceptions  : none

=cut

sub create_ticket {
    my ( $ticket, $parameters, $logger ) = @_;

    $logger->info( 'Creating' . ' "' . $ticket->{summary} . '" ... ' );

    # First check if the ticket already exists
    if (my $existing_ticket_key = $parameters->{existing_tickets}->{ ($parameters->{division} // '') . '--' . $ticket->{jira}->{summary} }) {
        $logger->info(
            'Skipped: This seems to be a duplicate of https://www.ebi.ac.uk/panda/jira/browse/'
                . $existing_ticket_key
                . "\n" );
        return $existing_ticket_key;
    }

    my $endpoint = 'rest/api/latest/issue';

    my $content = { 'fields' => $ticket->{jira} };
    my $response = post_request( $endpoint, $content, $parameters, $logger );

    my $ticket_key = decode_json( $response->content() )->{'key'};
    $logger->info( "Done\t" . $ticket_key . "\n" );
    return $ticket_key;
}

=head2 post_request

  Arg[1]      : String $endpoint - the request's endpoint
  Arg[2]      : Hashref $content - the request's content
  Arg[3]      : Hashref $parameters - parameters used for authorization
  Arg[4]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Example     : my $response = post_request( $endpoint, $content, $parameters, $logger )
  Description : Sends a POST request to the JIRA server
  Return type : HTTP::Response object
  Exceptions  : none

=cut

sub post_request {
    my ( $endpoint, $content, $parameters, $logger ) = @_;

    my $host = 'https://www.ebi.ac.uk/panda/jira/';
    my $url  = $host . $endpoint;
    $logger->info("Request on $url\n");
    my $json_content = encode_json($content);

    my $request = HTTP::Request->new( 'POST', $url );

    $request->authorization_basic( $parameters->{user},
        $parameters->{password} );
    $request->header( 'Content-Type' => 'application/json' );
    $request->content($json_content);

    my $agent    = LWP::UserAgent->new();
    my $response = $agent->request($request);

    if ( $response->code() == 401 ) {
        $logger->error( 'Your JIRA password is not correct. Please try again',
            0, 0 );
    }

    if ( $response->code() == 403 ) {
        $logger->error(
            'You do not have permission to submit JIRA tickets programmatically',
            0, 0
        );
    }

    if ( !$response->is_success() ) {
        my $error_message = $response->as_string();

        $logger->error( $error_message, 0, 0 );
    }

    return $response;
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

