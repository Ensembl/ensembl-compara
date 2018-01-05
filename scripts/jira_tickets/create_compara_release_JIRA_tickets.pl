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
    my ( $relco, $release, $password, $help, $tickets_tsv, $config );

    GetOptions(
        'relco=s'    => \$relco,
        'release=i'  => \$release,
        'password=s' => \$password,
        'p=s'        => \$password,
        'tickets=s'  => \$tickets_tsv,
        'config=s'   => \$config,
        'c=s'        => \$config,
        'help'       => \$help,
        'h'          => \$help,
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
    ( $relco, $release, $password, $tickets_tsv, $config )
        = set_parameters( $relco, $release, $password, $tickets_tsv, $config,
        $logger );

    # ---------------------------
    # read config file parameters
    # ---------------------------
    my $parameters = Config::Tiny->read($config);

    # check_dates($parameters);
    
    # integrate command line parameters to parameters object
    $parameters->{relco}    = $relco;
    $parameters->{password} = $password;
    $parameters->{release}  = $release;

    # ------------------
    # parse tickets file
    # ------------------
    my $tickets = parse_tickets_file( $parameters, $tickets_tsv, $logger );
    print Dumper($tickets);

    # --------------------------------
    # get existing tickets for current
    # release from the JIRA server
    # --------------------------------
    my $existing_tickets_response
        = post_request( 'rest/api/latest/search',
        { "jql" => 'fixVersion=Ensembl\\u0020'  . $parameters->{release} },
        $parameters, $logger );
    my $existing_tickets
        = decode_json( $existing_tickets_response->content() );

    # --------------------
    # check for duplicates
    # --------------------
    my %tickets_to_skip;
    for my $ticket ( @{$tickets} ) {
        my $duplicate = check_for_duplicate( $ticket, $existing_tickets );

        if ($duplicate) {
            $tickets_to_skip{ $ticket->{summary} } = $duplicate;
        }
    }

    # --------------------
    # validate JIRA fields
    # --------------------
    # for my $ticket ( @{$tickets} ) {

       # $logger->info( 'Validating' . ' "' . $ticket->{summary} . '" ... ' );

        # validate_fields( $ticket, $parameters, $logger );
        # $logger->info("Done\n");

    # }

    # -----------------------
    # create new JIRA tickets
    # -----------------------
    for my $ticket ( @{$tickets} ) {
        $logger->info( 'Creating' . ' "' . $ticket->{summary} . '" ... ' );

        # if the ticket to be submitted is a subtask then fetch the parent key and
        # replace the parent summary with the parent key
        if ( $ticket->{'issuetype'}->{'name'} eq 'Sub-task' ) {
            my $parent_key
                = get_parent_key( $ticket->{'parent'}, $parameters, $logger );
                $ticket->{'parent'} = { 'key'  => $parent_key };
        }

        if ( $tickets_to_skip{ $ticket->{summary} } ) {
            $logger->info(
                'Skipped: This seems to be a duplicate of https://www.ebi.ac.uk/panda/jira/browse/'
                    . $tickets_to_skip{ $ticket->{summary} }
                    . "\n" );
        }
        else {
            my $ticket_key = create_ticket( $ticket, $parameters, $logger );
            $logger->info( "Done\t" . $ticket_key . "\n" );
        }

    }

}

=head2 set_parameters

  Arg[1]      : String $relco - a Regulation team member name or JIRA username
  Arg[2]      : Integer $release - the EnsEMBL release version
  Arg[3]      : String $password - user's JIRA password
  Arg[4]      : String $tickets_tsv - path to the tsv file that holds the input
  Arg[5]      : String $config - path to the config file holding handover dates
  Arg[6]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Description : Makes sure that the parameters provided through the command line
                are valid and assigns default values to the ones which where not 
                supplied
  Return type : Listref
  Exceptions  : none

=cut

sub set_parameters {
    my ( $relco, $release, $password, $tickets_tsv, $config, $logger ) = @_;

    $relco = $ENV{'USER'} if !$relco;
    $relco = validate_user_name( $relco, $logger );

    $release = Bio::EnsEMBL::ApiVersion->software_version() if !$release;

    $tickets_tsv = $FindBin::Bin . '/jira_recurrent_tickets.tsv'
        if !$tickets_tsv;

    if ( !-e $tickets_tsv ) {
        $logger->error(
            'Tickets file '
                . $tickets_tsv
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

    printf( "\trelco: %s\n\trelease: %i\n\ttickets: %s\n\tconfig: %s\n",
        $relco, $release, $tickets_tsv, $config );
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

    return ( $relco, $release, $password, $tickets_tsv, $config );
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

# sub check_dates {
# }

=head2 parse_tickets_file

  Arg[1]      : Hashref $parameters - parameters from command line and config
  Arg[2]      : String $tickets_tsv - path to the tsv file that holds the input
  Arg[3]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Example     : my $tickets = parse_tickets_file( $parameters, $tickets_tsv, $logger );
  Description : Reads the tsv input file, replaces placeholder tags and returns
                a listref of tickets to be submitted
  Return type : Listref
  Exceptions  : none

=cut

sub parse_tickets_file {

    my ( $parameters, $tickets_tsv, $logger ) = @_;
    my @tickets;
    local $/ = "\r";
    open (my $tsv, '<:encoding(UTF-8)', $tickets_tsv) or die "Could not open file '$tickets_tsv' $!";;

#    my $header = readline $tsv;
    my $header = <$tsv>;
    chomp $header;
    while ( readline $tsv ) {
        my $line = $_;
        chomp $line;
        print "\n this is the raw line \n $line \n ";
        $line = replace_placeholders( $line, $parameters );
        print "\n this is the line after replace_placeholders sub \n $line \n ";
        my ($project,          $issue_type,  $summary,
            $parent_summary,   $assignee,
            $priority,         $fixVersions, $due_date,
            $component_string, $description
        ) = split /\t/, $line;

        if ($assignee) {
            $assignee = validate_user_name( $assignee, $logger );
        }
        
        my @components;
        my @comps = split /,/, $component_string;
        print "\n component!!!!!! \n";
        print Dumper(\@comps);
        for my $comp (@comps) {
            push @components, { 'name' => $comp };
        }

        my %ticket = (
            'project'     => { 'key'  => $project },
            'issuetype'   => { 'name' => $issue_type },
            'summary'     => $summary,
            # the parent summary is replaced by the parent key
            # just before the ticket submission
            'parent'      => $parent_summary,
            'assignee'    => { 'name' => $assignee },
            'priority'    => { 'name' => $priority },
            'fixVersions' => [
                { 'name' => $fixVersions },
                { 'name' => 'Ensembl ' . $parameters->{release} }
            ],
            'duedate'     => $due_date,
            'components'  => \@components,
            'description' => $description,
        );
        print "\n this is the ticket -------======= \n\n";
        print Dumper(\%ticket);
        # delete empty fields from ticket
        for my $key ( keys %ticket ) {
            if ( !$ticket{$key} ) {
                delete $ticket{$key};
            }
        }
        print "\n this is the ticket after deleting empty fields-------======= \n\n";
        print Dumper(\%ticket);
        push @tickets, \%ticket;
    }

    return \@tickets;
}

=head2 replace_placeholders

  Arg[1]      : String $line - One line from the tsv input file
  Arg[2]      : Hashref $parameters - parameters from command line and config
  Example     : $line = replace_placeholders( $line, $parameters );
  Description : Replaces the placeholder tags with valid values and returns a
                a new string
  Return type : String
  Exceptions  : none

=cut

sub replace_placeholders {
    my ( $line, $parameters ) = @_;

    $line =~ s/<RelCo>/$parameters->{relco}/g;
    $line =~ s/<version>/$parameters->{release}/g;
    $line =~ s/<preHandover_date>/$parameters->{dates}->{preHandover}/g;
    $line =~ s/<handover_date>/$parameters->{dates}->{handover}/g;
    $line =~ s/<codeBranching_date>/$parameters->{dates}->{codeBranching}/g;
    $line =~ s/<release_date>/$parameters->{dates}->{release}/g;

    return $line;
}

=head2 get_parent_key

  Arg[1]      : String $summary - Summary of the parent ticket
  Arg[2]      : Hashref $parameters - parameters from command line and config
  Arg[3]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Example     : my $parent_key
                = get_parent_key( $ticket->{'parent'}, $parameters, $logger );
  Description : Gets the ticket key of the parent task
  Return type : String
  Exceptions  : none

=cut

sub get_parent_key {
    my ( $summary, $parameters, $logger ) = @_;

    # jql=summary ~ "Update declarations" AND fixVersion %3D release-88
    my $content
        = {   "jql" => 'fixVersion=Ensembl\\u0020'
            . $parameters->{release}
            . ' and summary ~ "'
            . $summary
            . '"' };

    my $response = post_request( 'rest/api/latest/search',
        $content, $parameters, $logger );

    my $parent = decode_json( $response->content() )->{'issues'}->[0];

    return $parent->{'key'};
}

# sub validate_fields {
#     my ( $ticket, $parameters, $logger ) = @_;

#     # my %fields_to_be_validated = (
#     #     'project'     => 1,
#     #     'issuetype'   => 1,
#     #     'reporter'    => 1,
#     #     'assignee'    => 1,
#     #     'priority'    => 1,
#     #     'fixVersions' => 1,
#     #     'components'  => 1,
#     # );

#     my %fields_to_be_validated = (
#         'project'   => $ticket->{'project'}->{'key'},
#         'issuetype' => $ticket->{'issuetype'}->{'name'},
#         'reporter'  => $ticket->{'reporter'}->{'name'},
#         'priority'  => $ticket->{'priority'}->{'name'},

#         #     # 'fixversion' => 1,
#         #     # 'component'  => 1
#         ,
#     );

#     if ( $ticket->{'assignee'}->{'name'} ) {
#         $fields_to_be_validated{'assignee'} = $ticket->{'assignee'}->{'name'};
#     }

#     my $endpoint = 'rest/api/latest/search';

#     for my $key ( keys %fields_to_be_validated ) {
#         my $value = $fields_to_be_validated{$key};
#         my ( $response, $content );

#         # if ( $fields_to_be_validated{ lc $key } ) {
#         # if ( ref($value) ne 'ARRAY' ) {
#         $content = { "jql" => "$key = $value", "maxResults" => 1 };
#         $response = post_request( $endpoint, $content, $parameters, $logger );

#         # say $key . "\t" . $value;

#         # }
#         # else {
#         #     for my $element ( @{$value} ) {
#         #         $content
#         #             = { "jql" => "$key=$element", "maxResults" => 1 };
#         #         $response
#         #             = post_request( $endpoint, $content, $parameters,
#         #             $logger );
#         #         say $key . "\t" . $element;
#         #     }
#         # }
#         # }

#     }

# }

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
    my $endpoint = 'rest/api/latest/issue';

    my $content = { 'fields' => $ticket };
    my $response = post_request( $endpoint, $content, $parameters, $logger );

    return decode_json( $response->content() )->{'key'};
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
    print '\n\n-------------' . $url . "\n\n";
    my $json_content = encode_json($content);

    my $request = HTTP::Request->new( 'POST', $url );

    $request->authorization_basic( $parameters->{relco},
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
            'Your do not have permission to submit JIRA tickets programmatically',
            0, 0
        );
    }

    if ( !$response->is_success() ) {
        my $error_message = $response->as_string();

        $logger->error( $error_message, 0, 0 );
    }

    return $response;
}

=head2 check_for_duplicate

  Arg[1]      : Hashref $ticket - holds the data for the ticket which is about
                to be submitted
  Arg[2]      : Hashref $existing_tickets - holds the data for all tickets that
                already exist on the JIRA server for the current EnsEMBL release
  Example     : my $duplicate = check_for_duplicate($ticket, $existing_tickets);
  Description : Checks whether the ticket which is about to be submitted exists
                already on the JIRA server and returns the relevant key if this
                is true
  Return type : String
  Exceptions  : none

=cut

sub check_for_duplicate {
    my ( $ticket, $existing_tickets ) = @_;
    my $duplicate;

    for my $existing_ticket ( @{ $existing_tickets->{issues} } ) {
        if ( $ticket->{summary} eq $existing_ticket->{fields}->{summary} ) {
            $duplicate = $existing_ticket->{key};
            last;
        }
    }

    return $duplicate;
}

sub usage {
    print <<EOF;
=head1
create_JIRA_tickets.pl -relco <string> -password <string> -release <integer> -tickets <file> -config <file> 

-relco               JIRA username. Optional, will be inferred from current system user if not supplied.
-password | -p       JIRA password. Will need to be typed in standard input if not supplied.
-release             EnsEMBL Release. Optional, will be inferred from EnsEMBL API if not supplied.
-tickets             File that holds the input data for creating the JIRA tickets in tab separated format.
                     If not supplied, the script is looking for the default one 'jira_recurrent_tickets.tsv'
                     in the same directory as the executable.
-config              Configuration parameters file, currently holds the handover deadlines, may be expanded
                     in the future. If not supplied, the script is looking for the default one 'jira.conf'
                     in the same directory as the executable.
-help | -h           Prints this help text.

Reads the -tickets input file and creates JIRA tickets
EOF
    exit 0;
}

#TODO check date timeline
