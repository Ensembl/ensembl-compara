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

package Bio::EnsEMBL::Compara::Utils::JIRA;

use strict;
use warnings;

use JSON;
use HTTP::Request;
use LWP::UserAgent;
use Term::ReadKey;
use Bio::EnsEMBL::Utils::Logger;

use Data::Dumper;

sub json_to_jira {
    my ($self, $json_hash, $issuetype, $parameters, $logger) = @_;

    # We can define one or many components
    my @components;
    if ($json_hash->{'component'}) {
        push @components, { 'name' => $json_hash->{'component'} };
    } else {
        push @components, { 'name' => $_ } for @{$json_hash->{'components'}};
    }
    if ($parameters->{'tickets'}->{'component'}) {
        push @components, { 'name' => $parameters->{'tickets'}->{'component'} };
    } elsif ( $parameters->{'tickets'}->{'components'} ) {
        push @components, { 'name' => $_ } for @{$parameters->{'tickets'}->{'components'}};
    }

    my %ticket_fields = (
        'project'     => { 'key'  => $json_hash->{'project'} || $parameters->{'tickets'}->{'project'} },
        'issuetype'   => { 'name' => $issuetype },
        'summary'     => $self->_replace_placeholders( $json_hash->{'summary'}, $parameters ),
        'priority'    => { 'name' => $json_hash->{'priority'} || $parameters->{'tickets'}->{'priority'} },
        'fixVersions' => [
            { 'name' => $parameters->{'tickets'}->{'fixVersion'} },
        ],
        'components'  => \@components,
        'description' => $self->_replace_placeholders( $json_hash->{'description'}, $parameters ),
    );
    if ($parameters->{'division'}) {
        $ticket_fields{'customfield_11130'} = { 'value' => $parameters->{'division'} };
    }

    if ($json_hash->{'assignee'}) {
        $ticket_fields{'assignee'} = { 'name' => $self->validate_user_name( $self->_replace_placeholders( $json_hash->{'assignee'}, $parameters), $logger ) };
    }
    
    if ( $json_hash->{'labels'} ) {
        foreach my $label ( @{ $json_hash->{'labels'} } ) {
            $label =~ s/ /_/g; # JIRA doesn't allow whitespace in labels
            push( @{ $ticket_fields{'labels'} }, $label );
        }
    }

    if (my $name_on_graph = $json_hash->{'name_on_graph'}) {
        $name_on_graph =~ s/ /_/g;  # JIRA doesn't allow whitespace in labels
        push( @{ $ticket_fields{'labels'} }, "Graph:$name_on_graph" );
    }
    
    my $ticket = { 'fields' => \%ticket_fields };
    
    # if ( $json_hash->{'links'} ) {
    #     my @jira_links;
    #     foreach my $json_link ( @{ $json_hash->{'links'} } ) {
    #         my ($link_type, $link_key) = @$json_link;
    #         my $link = { "add" => {
    #             "type"         => { "name" => $link_type },
    #             "outwardIssue" => { "key"  => $link_key  }
    #         } };
    #         push( @jira_links, $link );
    #     }
    #     $ticket->{'update'}->{'issuelinks'} = \@jira_links;
    # }

    $json_hash->{'jira'} = $ticket;
    return $ticket;
}

=head2 _replace_placeholders

  Arg[1]      : String $line - One line from the json input file
  Arg[2]      : Hashref $parameters - parameters from command line and config
  Example     : $line = _replace_placeholders( $line, $parameters );
  Description : Replaces the placeholder tags with valid values and returns a
                a new string
  Return type : String
  Exceptions  : none

=cut

sub _replace_placeholders {
    my ( $self, $line, $parameters ) = @_;

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

=head2 validate_user_name

  Arg[1]      : String $user - a Compara team member name or JIRA username
  Arg[2]      : Bio::EnsEMBL::Utils::Logger $logger - object used for logging
  Example     : my $valid_user = validate_user_name($user, $logger)
  Description : Checks if the provided user name is valid, returns valid JIRA
                username
  Return type : String
  Exceptions  : none

=cut

sub validate_user_name {
    my ( $self, $user, $logger ) = @_;

    my %valid_user_names = (
        'carla'    => 'carlac',
        'carlac'   => 'carlac',
        'muffato'  => 'muffato',
        'matthieu' => 'muffato',
        'mateus'   => 'mateus',
        'jorge'    => 'jalvarez',
        'jalvarez' => 'jalvarez',
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
    my ( $self, $ticket, $parameters, $logger ) = @_;

    my $ticket_summary = $ticket->{fields}->{summary};
    $logger->info( 'Creating' . ' "' . $ticket_summary . '" ... ' );

    # First check if the ticket already exists
    if (my $existing_ticket_key = $parameters->{existing_tickets}->{ ($parameters->{division} // '') . '--' . $ticket_summary }) {
        $logger->info(
            'Skipped: This seems to be a duplicate of https://www.ebi.ac.uk/panda/jira/browse/'
                . $existing_ticket_key
                . "\n" );
        return $existing_ticket_key;
    }

    my $endpoint = 'rest/api/latest/issue';
    print "post_request($endpoint, $ticket, ....)\n";
    # print Dumper $ticket;
    my $response = $self->post_request( $endpoint, $ticket, $parameters, $logger );
    
    my $ticket_key = decode_json( $response->content() )->{'key'};
    $logger->info( "Done\t" . $ticket_key . "\n\n" );
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
    my ( $self, $endpoint, $content, $parameters, $logger ) = @_;

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

1;
