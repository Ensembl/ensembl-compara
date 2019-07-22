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

use Data::Dumper;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use Term::ReadKey;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::IO qw (slurp);
use Bio::EnsEMBL::Utils::Logger;

=head2 new

  Arg[1]      : (optional) string $user - a JIRA username. If not given, uses
                environment variable $USER as default.
  Arg[2]      : (optional) string $relco - a Compara RelCo JIRA username. By
                default, $user.
  Arg[3]      : (optional) string $division - a Compara division (can be empty
                for RelCo tickets). If not given, uses environment variable
                $COMPARA_DIV as default.
  Arg[4]      : (optional) int $release - Ensembl release version. If not given,
                uses environment variable $CURR_ENSEMBL_RELEASE as default.
  Arg[5]      : (optional) string $project - JIRA project name. By default,
                'ENSCOMPARASW'.
  Example     : my $jira_adaptor = new Bio::EnsEMBL::Compara::Utils::JIRA('user', 'relco', 'metazoa', 97);
  Description : Creates a new JIRA object
  Return type : Bio::EnsEMBL::Compara::Utils::JIRA object
  Exceptions  : none

=cut

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;
    my ( $user, $relco, $division, $release, $project ) = rearrange(
        [qw(USER RELCO DIVISION RELEASE PROJECT)], @_);
    my $self = {};
    bless $self, $class;
    # Initialize logger
    $self->{_logger} = Bio::EnsEMBL::Utils::Logger->new(-LOGLEVEL => 'info');
    # Set username that will be used to create the JIRA tickets
    if ($user) {
        $self->{_user} = $self->_validate_username($user);
    } else {
        $self->{_user} = $self->_validate_username($ENV{'USER'});
    }
    $self->{_relco} = ($relco) ? $self->_validate_username($relco) : $self->{_user};
    $self->{_project} = $project || 'ENSCOMPARASW';
    # If any of the following parameters are missing, get them from Compara
    # production environment
    # (https://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Production+Environment)
    if (defined $division) {
        # $division can be an empty string for RelCo tickets
        $self->{_division} = $self->_validate_division($division);
    } else {
        $self->{_division} = $self->_validate_division($ENV{'COMPARA_DIV'});
    }
    $self->{_release} = $release || $ENV{'CURR_ENSEMBL_RELEASE'};
    return $self;
}

=head2 create_tickets

  Arg[1]      : string $json_input - either a string in JSON format or a path to
                a JSON file where to find the JIRA ticket(s)
  Arg[2]      : (optional) string $issue_type - a JIRA issue type to set if no
                issue type is provided for a ticket. By default, 'Task'.
  Arg[3]      : (optional) string $priority - a JIRA priority to set if no
                priority is provided for a ticket. By default, 'Major'.
  Arg[4]      : (optional) arrayref of strings $components - a list of JIRA
                components to include the JIRA tickets. By default, no more
                components are added.
  Arg[5]      : (optional) arrayref of strings $labels - a list of JIRA labels
                to include in the JIRA tickets. By default, no more labels are
                added.
  Arg[6]      : (optional) boolean $dry_run - in dry-run mode, the JIRA tickets
                will not be submitted to the JIRA server. By default, dry-run
                mode is off.
  Example     : $jira_adaptor->create_tickets('jira_recurrent_tickets.vertebrates.json');
  Description : Submits a post request to the JIRA server that creates a new
                ticket. Returns the key of the created ticket.
  Return type : arrayref of strings (JIRA keys)
  Exceptions  : thrown on invalid $json_input

=cut

sub create_tickets {
    my $self = shift;
    my ( $json_input, $issue_type, $priority, $components, $labels, $dry_run ) = rearrange(
        [qw(JSON_INPUT ISSUE_TYPE PRIORITY COMPONENTS LABELS DRY_RUN)], @_);
    # Set default values for optional arguments
    $issue_type ||= 'Task';
    $priority ||= 'Major';
    $dry_run ||= 0;
    # Request password (if not available already)
    my $defined_password = defined $self->{_password};
    if (! $defined_password) {
        $self->{_password} = $self->_request_password();
    }
    # Read tickets from either a JSON formated string or a JSON file path
    my $json_ticket_list;
    eval { $json_ticket_list = decode_json($json_input) };
    # If $@ is not empty, decode_json() has raised an error. Thus, treat
    # $json_input as a file path.
    if ($@) {
        $json_ticket_list = decode_json(slurp($json_input))
            or die "Could not open file '$json_input' $!";
    }
    # Generate the list of JIRA tickets from each JSON hash
    my $jira_tickets = ();
    foreach my $json_ticket ( @$json_ticket_list ) {
        push @$jira_tickets,
             $self->_json_to_jira($json_ticket, $issue_type, $priority, $components, $labels);
        if ($json_ticket->{subtasks}) {
            foreach my $json_subtask ( @{$json_ticket->{subtasks}} ) {
                push @{$jira_tickets->[-1]->{subtasks}},
                     $self->_json_to_jira($json_subtask, 'Sub-task', $priority, $components, $labels);
            }
        }
    }
    # Log all generated JIRA tickets
    $self->{_logger}->info(Dumper($jira_tickets) . "\n");
    # Get all the tickets on the JIRA server for the same project, release and
    # division
    # NOTE: JQL queries require whitespaces to be in their Unicode equivalent
    my $fixVersion = 'Release\u0020' . $self->{_release};
    my $jql = sprintf('project=%s AND fixVersion=%s', $self->{_project}, $fixVersion);
    if ($self->{_division}) {
        $jql .= sprintf(' AND cf[11130]=%s', $self->{_division});
    } else {
        $jql .= ' AND cf[11130] IS EMPTY';
    }
    my $division_tickets = $self->fetch_tickets($jql);
    # Create a hash with the summary of each ticket and its corresponding
    # JIRA key
    my %existing_tickets = map {$_->{fields}->{summary} => $_->{key}} @{$division_tickets->{issues}};
    # Create the tickets, dicarding all for which there exists another ticket on
    # the JIRA server with an identical summary (for the same project, release
    # and division)
    my $ticket_key_list;
    my $base_url = 'https://www.ebi.ac.uk/panda/jira/browse/';
    foreach my $ticket ( @$jira_tickets ) {
        my $summary = $ticket->{fields}->{summary};
        if (exists $existing_tickets{$summary}) {
            my $ticket_key = $existing_tickets{$summary};
            my $issue_type = lc $ticket->{fields}->{issuetype}->{name};
            $self->{_logger}->info(
                sprintf("Skipped %s \"%s\". Likely a duplicate of %s%s\n",
                        $issue_type, $summary, $base_url, $ticket_key)
            );
            push @$ticket_key_list, $ticket_key;
        } else {
            # In dry-run mode, the message will be logged but the ticket will
            # not be created
            push @$ticket_key_list, $self->_create_new_ticket($ticket, $dry_run);
        }
        if ($ticket->{subtasks}) {
            foreach my $subtask ( @{$ticket->{subtasks}} ) {
                my $summary = $subtask->{fields}->{summary};
                if (exists $existing_tickets{$summary}) {
                    my $ticket_key = $existing_tickets{$summary};
                    my $issue_type = lc $subtask->{fields}->{issuetype}->{name};
                    $self->{_logger}->info(
                        sprintf("Skipped %s \"%s\". Likely a duplicate of %s%s\n",
                                $issue_type, $summary, $base_url, $ticket_key)
                    );
                    push @$ticket_key_list, $ticket_key;
                } else {
                    # Link the subtask with its parent ticket
                    $subtask->{'fields'}->{'parent'} = { 'key' => $ticket_key_list->[-1] };
                    # In dry-run mode, the message will be logged but the ticket
                    # will not be created
                    push @$ticket_key_list, $self->_create_new_ticket($subtask, $dry_run);
                }
            }
        }
    }
    # If the password was requested for this task, forget it before returning
    if (! $defined_password) {
        undef $self->{_password};
    }
    return $ticket_key_list;
}

=head2 fetch_tickets

  Arg[1]      : string $jql - JQL (JIRA Query Language) query
  Arg[2]      : (optional) int $max_results - maximum number of matching tickets
                to return. By default, 300.
  Example     : my $tickets = $jira_adaptor->fetch_tickets('project=ENSCOMPARASW AND priority=Major');
  Description : Returns up to $max_results tickets that match the given JQL
                query
  Return type : arrayref of JIRA tickets
  Exceptions  : none

=cut

sub fetch_tickets {
    my ( $self, $jql, $max_results ) = @_;
    # Set default values for optional arguments
    $max_results ||= 300;
    # Request password (if not available already)
    my $defined_password = defined $self->{_password};
    if (! $defined_password) {
        $self->{_password} = $self->_request_password();
    }
    # Send a search POST request for the given JQL query
    my $tickets =  $self->_post_request(
        'search', {'jql' => $jql, 'maxResults' => $max_results});
    # If the password was requested for this task, forget it before returning
    if (! $defined_password) {
        undef $self->{_password};
    }
    return $tickets;
}

=head2 link_tickets

  Arg[1]      : string $link_type - an issue link type
  Arg[2]      : string $inward_key - inward JIRA ticket key
  Arg[3]      : string $outward_key - outward JIRA ticket key
  Arg[4]      : (optional) boolean $dry_run - in dry-run mode, the issue links
                will not be submitted to the JIRA server. By default, dry-run
                mode is off.
  Example     : $jira_adaptor->link_tickets('Duplicate', 'ENCOMPARASW-1452', 'ENCOMPARASW-2145');
  Description : Creates an issue link of the given type between the two tickets.
                For more information, go to
                https://www.ebi.ac.uk/panda/jira/rest/api/latest/issueLinkType
  Return type : none
  Exceptions  : none

=cut

sub link_tickets {
    my $self = shift;
    my ( $link_type, $inward_key, $outward_key, $dry_run ) = rearrange(
        [qw(LINK_TYPE INWARD_KEY OUTWARD_KEY DRY_RUN)], @_);
    # Set default values for optional arguments
    $dry_run ||= 0;
    # Request password (if not available already)
    my $defined_password = defined $self->{_password};
    if (! $defined_password) {
        $self->{_password} = $self->_request_password();
    }
    # Check if the issue link type requested is correct
    my %jira_link_types = map { $_ => 1 } ('After', 'Before', 'Blocks', 'Cloners', 'Duplicate',
                                           'Issue split', 'Related', 'Relates', 'Required');
    if (exists $jira_link_types{$link_type}) {
        my $link_content = {
            "type"         => { "name" => $link_type },
            "inwardIssue"  => { "key"  => $inward_key },
            "outwardIssue" => { "key"  => $outward_key }
        };
        # Create the issue link for the given tickets via POST request
        $self->{_logger}->info(sprintf('Creating link "%s" between %s and %s ... ',
                                       $link_type, $inward_key, $outward_key));
        if ($dry_run) {
            $self->{_logger}->info("\n");
            $self->{_logger}->info(Dumper $link_content);
        } else {
            $self->_post_request('issueLink', $link_content);
        }
        $self->{_logger}->info("Done.\n");
    } else {
        my $type_list = join("\n", sort keys %jira_link_types);
        $self->{_logger}->error("Unexpected link type '$link_type'! Allowed link types:\n$type_list");
    }
    # If the password was requested for this task, forget it before returning
    if (! $defined_password) {
        undef $self->{_password};
    }
}

=head2 _validate_username

  Arg[1]      : string $user - a JIRA username
  Example     : my $user = $jira_adaptor->_validate_username('username');
  Description : Checks if the provided username is valid, and if so, returns it
  Return type : string
  Exceptions  : none

=cut

sub _validate_username {
    my ( $self, $user ) = @_;
    my %compara_members = map { $_ => 1 } qw(carlac jalvarez mateus muffato);
    # Do a case insensitive user matching
    if (exists $compara_members{lc $user}) {
        return lc $user;
    } else {
        my $user_list = join("\n", sort keys %compara_members);
        $self->{_logger}->error("Unexpected user '$user'! Allowed user names:\n$user_list");
    }
}

=head2 _validate_division

  Arg[1]      : string $division - a Compara division (can be empty for RelCo
                tickets)
  Example     : my $division = $jira_adaptor->_validate_division('vertebrates');
  Description : Checks if the provided division is valid, and if so, returns its
                upper case equivalent
  Return type : string
  Exceptions  : none

=cut

sub _validate_division {
    my ( $self, $division ) = @_;
    my %compara_divisions = map { $_ => 1 } qw(vertebrates plants citest ensembl grch37 metazoa);
    # RelCo tickets do not need a specific division
    if ($division eq '') {
        return $division;
    # Do a case insensitive division matching
    } elsif (exists $compara_divisions{lc $division}) {
        my $lc_division = lc $division;
        # Return the upper case equivalent of the division
        if ($lc_division eq 'citest') {
            return 'CITest';
        } elsif ($lc_division eq 'grch37') {
            return 'GRCh37';
        } else {
            return ucfirst $lc_division;
        }
    } else {
        my $division_list = join("\n", sort keys %compara_divisions);
        $self->{_logger}->error("Unexpected division '$division'! Allowed divisions:\n$division_list");
    }
}

=head2 _json_to_jira

  Arg[1]      : hashref of strings $json_hash - a JSON hash JIRA ticket
  Arg[2]      : string $issue_type - a JIRA issue type to set if no issue type
                is provided in $json_hash
  Arg[3]      : string $priority - a JIRA priority to set if no priority is
                provided in $json_hash
  Arg[4]      : (optional) arrayref of strings $components - a list of JIRA
                components to include in the JIRA ticket
  Arg[5]      : (optional) arrayref of strings $labels - a list of JIRA labels
                to include in the JIRA ticket
  Example     : my $json_hash = { "summary": "Example task",
                                  "description": "Example for Bio::EnsEMBL::Compara::Utils::JIRA"
                                };
                my $components = ('Test suite');
                my $labels = ('Example');
                my $ticket = $jira_adaptor->_json_to_jira($json_hash, 'Task', 'Minor', $components, $labels);
  Description : Converts the JIRA ticket information provided in the JSON hash
                to its equivalent JIRA hash and returns it
  Return type : hashref of hashes following the structure of a JIRA ticket
  Exceptions  : none

=cut

sub _json_to_jira {
    my ( $self, $json_hash, $issue_type, $priority, $components, $labels ) = @_;
    my %jira_hash;
    $jira_hash{'project'}     = { 'key' => $self->{_project} };
    $jira_hash{'summary'}     = $self->_replace_placeholders($json_hash->{'summary'});
    $jira_hash{'issuetype'}   = { 'name' => $json_hash->{'issuetype'} // $issue_type };
    $jira_hash{'priority'}    = { 'name' => $json_hash->{'priority'} // $priority };
    $jira_hash{'fixVersions'} = [{ 'name' => 'Release ' . $self->{_release} }];
    $jira_hash{'description'} = $self->_replace_placeholders($json_hash->{'description'});
    # $jira_hash{'components'}
    if ($json_hash->{'component'}) {
        push @{$jira_hash{'components'}}, { 'name' => $json_hash->{'component'} };
    } elsif ($json_hash->{'components'}) {
        push @{$jira_hash{'components'}}, { 'name' => $_ } for @{$json_hash->{'components'}};
    }
    if ($components) {
        push @{$jira_hash{'components'}}, { 'name' => $_ } for @{$components};
    }
    # $jira_hash{'labels'}
    my @label_list;
    if ($json_hash->{'labels'}) {
        push @label_list,  $json_hash->{'labels'};
    }
    if ($labels) {
        push @label_list, $labels;
    }
    if ($json_hash->{'name_on_graph'}) {
        push @label_list, 'Graph:' . $json_hash->{'name_on_graph'};
    }
    foreach my $label ( @label_list ) {
        # JIRA does not allow whitespace in labels
        $label =~ s/ /_/g;
        push @{$jira_hash{'labels'}}, $label;
    }
    # $jira_hash{'division'}
    if ($self->{_division} ne '') {
        $jira_hash{'customfield_11130'} = { 'value' => $self->{_division} };
    }
    # $jira_hash{'assignee'}
    if ($json_hash->{'assignee'}) {
        my $assignee = $self->_replace_placeholders($json_hash->{'assignee'});
        $jira_hash{'assignee'} = { 'name' => $self->_validate_username($assignee) };
    }
    # $jira_hash{'parent'}
    if ($json_hash->{'parent'}) {
        $jira_hash{'parent'} = { 'key' => $json_hash->{'parent'} };
    }
    # Create JIRA ticket and return it
    my $ticket = { 'fields' => \%jira_hash };
    return $ticket;
}

=head2 _replace_placeholders

  Arg[1]      : string $field_value - value of a JIRA ticket field
  Example     : my $value = $jira_adaptor->_replace_placeholders(
                    '"summary": "<Division> Release <version> Ticket"');
  Description : Replaces the placeholder tags in the given field value by their
                corresponding values and returns the new field value
  Return type : string
  Exceptions  : none

=cut

sub _replace_placeholders {
    my ( $self, $field_value ) = @_;
    if ($field_value) {
        $field_value =~ s/<RelCo>/$self->{_relco}/g;
        $field_value =~ s/<version>/$self->{_release}/g;
        if ($self->{_division}) {
            $field_value =~ s/<Division>/$self->{_division}/g;
            my $lc_division = lc $self->{_division};
            $field_value =~ s/<division>/$lc_division/g;
        }
    }
    return $field_value;
}

=head2 _request_password

  Example     : my $password = $jira_adaptor->_request_password();
  Description : Asks for the password of the given JIRA user. WARNING: the
                password is returned as plain text, i.e. without encryption.
  Return type : string
  Exceptions  : none

=cut

sub _request_password {
    my $self = shift;
    my $user = $self->{_user};
    print "\nPlease, type the JIRA password for user '$user':";
    # Make password invisible on terminal
    ReadMode('noecho');
    my $password = ReadLine(0);
    chomp $password;
    # Restore typing visibility on terminal
    ReadMode(0);
    print "\n\n";
    return $password;
}

=head2 _create_new_ticket

  Arg[1]      : hashref $ticket - a JIRA ticket to be created
  Arg[2]      : int $dry_run - in dry-run mode, the JIRA ticket will not be
                submitted to the JIRA server
  Example     : my $ticket = {
                    'priority'    => { 'name' => 'Minor' },
                    'project'     => { 'key' => 'ENSCOMPARASW' },
                    'fixVersions' => [{ 'name' => 'Release 98' }],
                    'issuetype'   => { 'name' => 'Task' },
                    'description' => 'Example for Bio::EnsEMBL::Compara::Utils::JIRA',
                    'labels'      => ['Example'],
                    'summary'     => 'Example task'
                };
                my $ticket_key = $jira_adaptor->_create_new_ticket($ticket, 0);
  Description : Creates the JIRA ticket unless its summary is in
                $existing_tickets, and returns its JIRA key
  Return type : string
  Exceptions  : none

=cut

sub _create_new_ticket {
    my ( $self, $ticket, $dry_run ) = @_;
    my $issue_type = lc $ticket->{fields}->{issuetype}->{name};
    my $summary = $ticket->{fields}->{summary};
    $self->{_logger}->info(sprintf('Creating %s "%s" ... ', $issue_type, $summary));
    my $ticket_key;
    if ($dry_run) {
        $ticket_key = 'None [dry-run ON]';
    } else {
        my $new_ticket = $self->_post_request('issue', $ticket);
        my $ticket_key = $new_ticket->{key};
    }
    $self->{_logger}->info(sprintf("Done. Key assigned: %s\n", $ticket_key));
    return $ticket_key;
}

=head2 _post_request

  Arg[1]      : string $action - a POST request's action to perform, i.e.
                'issue' (to create new JIRA tickets) or 'search'
  Arg[2]      : hashref $content_data - a POST request's content data
  Example     : my $tickets = $jira_adaptor->_post_request(
                    'search', {'jql' => 'project=ENSCOMPARASW', 'maxResults' => 10});
  Description : Sends a POST request to the JIRA server and returns the response
  Return type : arrayref of JIRA tickets
  Exceptions  : none

=cut

sub _post_request {
    my ( $self, $action, $content_data ) = @_;
    # Check if the action requested is available
    my %available_actions = map { $_ => 1 } qw(issue search issueLink);
    if (! exists $available_actions{$action}) {
        my $action_list = join("\n", sort keys %available_actions);
        $self->{_logger}->error(
            "Unexpected POST request '$action'! Allowed options:\n$action_list",
            0, 0
        );
    }
    # Create the HTTP POST request and LWP objects to get the response for the
    # given $action and $content_data
    my $url = 'https://www.ebi.ac.uk/panda/jira/rest/api/latest/' . $action;
    $self->{_logger}->debug("POST Request on $url\n");
    my $request = HTTP::Request->new('POST', $url);
    # Request password (if not available already)
    my $defined_password = defined $self->{_password};
    if (! $defined_password) {
        $self->{_password} = $self->_request_password();
    }
    $request->authorization_basic($self->{_user}, $self->{_password});
    # The content data will be sent in JSON format
    $request->header('Content-Type' => 'application/json');
    my $json_content = encode_json($content_data);
    $request->content($json_content);
    my $agent    = LWP::UserAgent->new();
    my $response = $agent->request($request);
    # Check and report possible errors
    if ($response->code() == 401) {
        $self->{_logger}->error(
            'Incorrect JIRA password. Please, try again.', 0, 0);
    } elsif ($response->code() == 403) {
        my $user = $self->{_user};
        $self->{_logger}->error(
            "User '$user' unauthorised to handle JIRA tickets programmatically",
            0, 0
        );
    } elsif (! $response->is_success()) {
        my $error_message = $response->as_string();
        $self->{_logger}->error($error_message, 0, 0);
    }
    # If the password was requested for this task, forget it before returning
    if (! $defined_password) {
        undef $self->{_password};
    }
    # Return the response content
    return decode_json($response->content());
}

1;
