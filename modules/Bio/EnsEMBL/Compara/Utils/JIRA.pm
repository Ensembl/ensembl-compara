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

# JIRA identifiers of the custom field used in Compara (ENSCOMPARASW)
use constant DIVISION_CUSTOM_FIELD_ID => 'customfield_11130';
use constant CATEGORY_CUSTOM_FIELD_ID => 'customfield_11333';
use constant EPIC_LINK_CUSTOM_FIELD_ID => 'customfield_10236';

# Used to automatically populate the category when none is given
my %component_to_category = (
    'Relco tasks'       => 'Production::Relco',
    'Production tasks'  => 'Production::Tasks',
);

=head2 new

  Arg[-USER]     : (optional) string - a JIRA username. If not given, uses
                   environment variable $USER as default.
  Arg[-RELCO]    : (optional) string - a Compara RelCo JIRA username. By
                   default, $user.
  Arg[-DIVISION] : (optional) string - a Compara division (can be empty for
                   RelCo tickets). If not given, uses environment variable
                   $COMPARA_DIV as default.
  Arg[-RELEASE]  : (optional) int/string - Ensembl release version. If not
                   given, uses environment variable $CURR_ENSEMBL_RELEASE as
                   default.
  Arg[-PROJECT]  : (optional) string - JIRA project name. By default,
                   'ENSCOMPARASW'.
  Arg[-LOGLEVEL] : (optional) string - log verbosity (accepted values defined at
                   Bio::EnsEMBL::Utils::Logger->level_defs). By default, 'info'.
  Example     : my $jira_adaptor = new Bio::EnsEMBL::Compara::Utils::JIRA('user', 'relco', 'metazoa', 97);
  Description : Creates a new JIRA object
  Return type : Bio::EnsEMBL::Compara::Utils::JIRA object
  Exceptions  : none

=cut

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;
    my ( $user, $relco, $division, $release, $project, $loglevel ) = rearrange(
        [qw(USER RELCO DIVISION RELEASE PROJECT LOGLEVEL)], @_);
    my $self = {};
    bless $self, $class;
    # Initialize logger
    $self->{_logger} = Bio::EnsEMBL::Utils::Logger->new(-LOGLEVEL => $loglevel || 'info');
    # Set username that will be used to create the JIRA tickets
    $self->{_user} = $user || $ENV{'USER'};
    $self->{_relco} = $relco || $self->{_user};
    $self->{_project} = $project || 'ENSCOMPARASW';

    if ( $ENV{'JIRA_AUTH_TOKEN'} ) {
        # this token should be your 'user:pass' string encoded to base64
        # export JIRA_AUTH_TOKEN=$(echo -n 'user:pass' | openssl base64)
        # https://developer.atlassian.com/server/jira/platform/basic-authentication/
        $self->{_auth_token} = $ENV{'JIRA_AUTH_TOKEN'};
        print STDERR "Authenticating with token '" . $self->{_auth_token} . "'\n";
    } else {
        # initialise user's password interactively
        print STDERR "Authenticating with username and password\n";
        $self->{_password} = $self->_request_password();
    }

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

  Arg[-JSON_STR]     : string - a string in JSON format with the JIRA ticket(s)
  Arg[-JSON_FILE]    : string - a path to a JSON file where to find the JIRA
                       ticket(s)
  Arg[-JSON_OBJ]     : hashref or arrayref - a hash or array of hashes with the
                       JIRA ticket(s)
  Arg[-DEFAULT_ISSUE_TYPE]
                     : (optional) string - a JIRA issue type to set if not issue
                       type is provided for a ticket. By default, 'Task'.
  Arg[-DEFAULT_PRIORITY]
                     : (optional) string - a JIRA priority to set if no priority
                       is provided for a ticket. By default, 'Major'.
  Arg[-EXTRA_COMPONENTS]
                     : (optional) arrayref of strings - a list of JIRA
                       components to include the JIRA tickets. By default, no
                       more components are added.
  Arg[-EXTRA_CATEGORIES]
                     : (optional) arrayref of strings - a list of JIRA
                       categories to include the JIRA tickets. By default, the
                       module will try to populate the categories from the
                       components on tickets that have no categories.
  Arg[-EXTRA_LABELS] : (optional) arrayref of strings - a list of JIRA labels to
                       include in the JIRA tickets. By default, no more labels
                       are added.
  Arg[-EPIC_LINK]    : (optional) string - a JIRA Epic ticket key to link the
                       JIRA tickets to
  Arg[-UPDATE]       : (optional) boolean - update the JIRA tickets if they
                       already exist, i.e. reopen the tickets, update their
                       description and remove the previous assignee. By default,
                       the tickets are not updated.
  Arg[-DRY_RUN]      : (optional) boolean - in dry-run mode, the JIRA tickets
                       will not be submitted to the JIRA server. By default,
                       dry-run mode is off.
  Example     : $jira_adaptor->create_tickets(-JSON_FILE => 'conf/vertebrates/jira_recurrent_tickets.json');
  Description : Submits a post request to the JIRA server that creates the new
                ticket(s). Returns an arrayref with the key of each ticket
                created. If there is a ticket already in the JIRA server that
                has the same summary as a ticket to be created, it will not be
                created and the key of the existing ticket will be returned
                instead.
  Return type : arrayref of strings (JIRA keys)
  Exceptions  : thrown on: invalid $json_str xor missing/invalid content in
                $json_file xor missing $json_obj

=cut

sub create_tickets {
    my $self = shift;
    my ( $json_str, $json_file, $json_obj, $default_issue_type, $default_priority, $extra_components, $extra_categories, $extra_labels, $epic_link, $update, $dry_run ) =
        rearrange([qw(JSON_STR JSON_FILE JSON_OBJ DEFAULT_ISSUE_TYPE DEFAULT_PRIORITY EXTRA_COMPONENTS EXTRA_CATEGORIES EXTRA_LABELS EPIC_LINK UPDATE DRY_RUN)], @_);
    # Read tickets from either a JSON formated string or a JSON file path
    my $json_ticket_list;
    if ($json_str) {
        $json_ticket_list = decode_json($json_str);
    } elsif ($json_file) {
        $json_ticket_list = decode_json(slurp($json_file)) or die "Could not open file '$json_file' $!";
    } elsif ($json_obj) {
        $json_ticket_list = $json_obj;
    } else {
        die "Required one of these three arguments: JSON_STR, JSON_FILE or JSON_OBJ";
    }
    # Ensure $json_ticket_list is an arrayref
    $json_ticket_list = [$json_ticket_list] if (ref $json_ticket_list eq 'HASH');
    # Set default values for optional arguments
    $default_issue_type ||= 'Task';
    $default_priority   ||= 'Major';
    $dry_run            ||= 0;
    # Generate the list of JIRA tickets from each JSON hash
    my $jira_tickets = ();
    foreach my $json_ticket ( @$json_ticket_list ) {
        push @$jira_tickets,
             $self->_json_to_jira($json_ticket, $default_issue_type, $default_priority, $extra_components, $extra_categories, $extra_labels, $epic_link);
        if ($json_ticket->{subtasks}) {
            foreach my $json_subtask ( @{$json_ticket->{subtasks}} ) {
                # NOTE: Sub-task tickets inherit the epic link from their parent task
                push @{$jira_tickets->[-1]->{subtasks}},
                     $self->_json_to_jira($json_subtask, 'Sub-task', $default_priority, $extra_components, $extra_categories, $extra_labels);
            }
        }
    }
    # Log all generated JIRA tickets
    $self->{_logger}->info(Dumper($jira_tickets) . "\n");
    # Get all the tickets on the JIRA server for the same project, release and
    # division
    my $division_tickets = $self->fetch_tickets();
    # Create a hash with the summary of each ticket and its corresponding
    # JIRA key
    my %existing_tickets = map {$_->{fields}->{summary} => $_->{key}} @{$division_tickets->{issues}};
    # Create the tickets, discarding all for which there exists another ticket on
    # the JIRA server with an identical summary (for the same project, release
    # and division)
    my $ticket_key_list;
    my $base_url = 'https://www.ebi.ac.uk/panda/jira/browse/';
    foreach my $ticket ( @$jira_tickets ) {
        my $summary = $ticket->{fields}->{summary};
        if (exists $existing_tickets{$summary}) {
            my $ticket_key = $existing_tickets{$summary};
            if ($update) {
                $self->_update_ticket($ticket_key, $ticket->{fields}->{description}, $dry_run);
            } else {
                my $issue_type = lc $ticket->{fields}->{issuetype}->{name};
                $self->{_logger}->info(
                    sprintf("Skipped %s \"%s\". Likely a duplicate of %s%s\n",
                            $issue_type, $summary, $base_url, $ticket_key)
                );
            }
            push @$ticket_key_list, $ticket_key;
        } else {
            # In dry-run mode, the message will be logged but the ticket will
            # not be created
            push @$ticket_key_list, $self->_create_new_ticket($ticket, $dry_run);
        }
        if ($ticket->{subtasks}) {
            # Save parent JIRA ticket key to link all the subtasks with it
            my $parent_ticket_key = $ticket_key_list->[-1];
            foreach my $subtask ( @{$ticket->{subtasks}} ) {
                my $summary = $subtask->{fields}->{summary};
                if (exists $existing_tickets{$summary}) {
                    my $ticket_key = $existing_tickets{$summary};
                    if ($update) {
                        $self->_update_ticket($ticket_key, $subtask->{fields}->{description}, $dry_run);
                    } else {
                        my $issue_type = lc $subtask->{fields}->{issuetype}->{name};
                        $self->{_logger}->info(
                            sprintf("Skipped %s \"%s\". Likely a duplicate of %s%s\n",
                                    $issue_type, $summary, $base_url, $ticket_key)
                        );
                    }
                    push @$ticket_key_list, $ticket_key;
                } else {
                    # Link the subtask with its parent ticket
                    $subtask->{'fields'}->{'parent'} = { 'key' => $parent_ticket_key };
                    # In dry-run mode, the message will be logged but the ticket
                    # will not be created
                    push @$ticket_key_list, $self->_create_new_ticket($subtask, $dry_run);
                }
            }
        }
    }
    return $ticket_key_list;
}

=head2 fetch_tickets

  Arg[-JQL]         : (optional) string - JQL (JIRA Query Language) query
  Arg[-MAX_RESULTS] : (optional) int - maximum number of matching tickets to
                      return. By default, 300.
  Example     : my $tickets = $jira_adaptor->fetch_tickets('priority=Major');
  Description : Returns up to $max_results tickets that match the given JQL
                query for the given project, release and division
  Return type : arrayref of JIRA tickets
  Exceptions  : none

=cut

sub fetch_tickets {
    my $self = shift;
    my ( $jql, $max_results ) = rearrange([qw(JQL MAX_RESULTS)], @_);
    # Set default values for optional arguments
    $max_results ||= 300;
    # Add the restrictions to fetch only tickets for the given project, release
    # and division
    # NOTE: JQL queries require whitespaces to be in their Unicode equivalent
    my $fixVersion = 'Ensembl\u0020' . $self->{_release};
    my $final_jql = sprintf('project=%s AND fixVersion=%s', $self->{_project}, $fixVersion);
    if ($self->{_division}) {
        $final_jql .= sprintf(' AND cf[11130]=%s', $self->{_division});
    } else {
        $final_jql .= ' AND cf[11130] IS EMPTY';
    }
    $final_jql .= " AND $jql" if ($jql);
    # Send a search POST request for the given JQL query
    my $tickets = $self->_post_request('search', {'jql' => $final_jql, 'maxResults' => $max_results});
    return $tickets;
}

=head2 get_ticket

  Arg[1]      : string - JIRA ticket key or ID
  Example     : my $ticket = $jira_adaptor->get_ticket('ENSCOMPARASW-4300');
  Description : Returns JIRA ticket JSON representation from API
  Return type : hashref of JIRA ticket JSON representation
  Exceptions  : none

=cut

sub get_ticket {
    my ( $self, $key_or_id ) = @_;
    my $url = "https://www.ebi.ac.uk/panda/jira/rest/api/latest/issue/$key_or_id";
    my $ticket = $self->_http_request('GET', $url);
    return $ticket->{fields};
}

=head2 link_tickets

  Arg[-LINK_TYPE]   : string - an issue link type
  Arg[-INWARD_KEY]  : string - inward JIRA ticket key
  Arg[-OUTWARD_KEY] : string - outward JIRA ticket key
  Arg[-DRY_RUN]     : (optional) boolean - in dry-run mode, the issue links will
                      not be submitted to the JIRA server. By default, dry-run
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
    # Check if the issue link type requested is correct
    my %jira_link_types = map { $_ => 1 } ('After', 'Before', 'Blocks', 'Cloners', 'Duplicate',
                                           'Issue split', 'Related', 'Relates', 'Required');
    if (exists $jira_link_types{$link_type}) {
        my $inward_ticket = $self->get_ticket($inward_key);
        my $link_exists = 0;
        foreach my $i ( @{$inward_ticket->{issuelinks}} ){
            if ($i->{type}->{name} eq $link_type && $i->{outwardIssue}->{key} eq $outward_key) {
                $link_exists = 1;
                last;
            }
        }
        if ( $link_exists == 1 ) {
            $self->{_logger}->info("Issue link already exists. Doing nothing.\n");
            return;
        }
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
    my %compara_divisions = map { $_ => 1 } qw(vertebrates plants ensembl metazoa bacteria pan protists fungi);
    # RelCo tickets do not need a specific division
    if ($division eq '') {
        return $division;
    # Do a case insensitive division matching
    } elsif (exists $compara_divisions{lc $division}) {
        # Return the division with the first character in uppercase
        return ucfirst lc $division;
    } else {
        my $division_list = join("\n", sort keys %compara_divisions);
        $self->{_logger}->error("Unexpected division '$division'! Allowed divisions:\n$division_list");
    }
}

=head2 _json_to_jira

  Arg[1]      : hashref $json_hash - a JSON hash JIRA ticket
  Arg[2]      : string $default_issue_type - a JIRA issue type to set if no
                issue type is provided in $json_hash
  Arg[3]      : string $default_priority - a JIRA priority to set if no priority
                is provided in $json_hash
  Arg[4]      : (optional) arrayref of strings $extra_components - a list of
                JIRA components to include in the JIRA ticket
  Arg[5]      : (optional) arrayref of strings $extra_categories - a list of
                JIRA categories to include in the JIRA ticket
  Arg[6]      : (optional) arrayref of strings $extra_labels - a list of JIRA
                labels to include in the JIRA ticket
  Arg[7]      : (optional) string $epic_link - a JIRA Epic ticket key to link
                the JIRA tickets to
  Example     : my $json_hash = {
                    "summary" => "Example task",
                    "description" => "Example for Bio::EnsEMBL::Compara::Utils::JIRA"
                };
                my $components = ['Test suite'];
                my $categories = ['Process::Optimisation'];
                my $labels = ['Example'];
                my $ticket = $jira_adaptor->_json_to_jira($json_hash, 'Task', 'Minor', $components, $categories, $labels);
  Description : Converts the JIRA ticket information provided in the JSON hash
                to its equivalent JIRA hash and returns it
  Return type : hashref of hashes following the structure of a JIRA ticket
  Exceptions  : none

=cut

sub _json_to_jira {
    my ( $self, $json_hash, $default_issue_type, $default_priority, $extra_components, $extra_categories, $extra_labels, $epic_link ) = @_;
    my %jira_hash;
    $jira_hash{'project'}     = { 'key' => $self->{_project} };
    $jira_hash{'summary'}     = $self->_replace_placeholders($json_hash->{'summary'});
    $jira_hash{'issuetype'}   = { 'name' => $json_hash->{'issuetype'} // $default_issue_type };
    $jira_hash{'priority'}    = { 'name' => $json_hash->{'priority'} // $default_priority };
    $jira_hash{'fixVersions'} = [{ 'name' => 'Ensembl ' . $self->{_release} }];
    $jira_hash{'description'} = $self->_replace_placeholders($json_hash->{'description'}) // "";
    # $jira_hash{'components'}
    $jira_hash{'components'} = [];
    if ($json_hash->{'component'}) {
        push @{$jira_hash{'components'}}, { 'name' => $json_hash->{'component'} };
    } elsif ($json_hash->{'components'}) {
        push @{$jira_hash{'components'}}, { 'name' => $_ } for @{$json_hash->{'components'}};
    }
    if ($extra_components) {
        push @{$jira_hash{'components'}}, { 'name' => $_ } for @{$extra_components};
    }
    # $jira_hash{'categories'}
    $jira_hash{CATEGORY_CUSTOM_FIELD_ID()} = [];
    if ($json_hash->{'category'}) {
        push @{$jira_hash{CATEGORY_CUSTOM_FIELD_ID()}}, { 'value' => $json_hash->{'category'} };
    } elsif ($json_hash->{'categories'}) {
        push @{$jira_hash{CATEGORY_CUSTOM_FIELD_ID()}}, { 'value' => $_ } for @{$json_hash->{'categories'}};
    }
    if ($extra_categories) {
        push @{$jira_hash{CATEGORY_CUSTOM_FIELD_ID()}}, { 'value' => $_ } for @{$extra_categories};
    }
    unless (scalar(@{$jira_hash{CATEGORY_CUSTOM_FIELD_ID()}})) {
        # Fallback to automatically set the categories from the component names
        foreach my $component (map {$_->{'name'}} @{$jira_hash{'components'}}) {
            if (exists $component_to_category{$component}) {
                push @{$jira_hash{CATEGORY_CUSTOM_FIELD_ID()}}, { 'value' => $component_to_category{$component} };
            }
        }
    }
    # $jira_hash{'labels'}
    my @label_list;
    $jira_hash{'labels'} = [];
    if ($json_hash->{'labels'}) {
        push @label_list, @{$json_hash->{'labels'}};
    }
    if ($extra_labels) {
        push @label_list, @{$extra_labels};
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
        $jira_hash{DIVISION_CUSTOM_FIELD_ID()} = { 'value' => $self->{_division} };
    }
    # $jira_hash{'assignee'}
    if ($json_hash->{'assignee'}) {
        my $assignee = $self->_replace_placeholders($json_hash->{'assignee'});
        $jira_hash{'assignee'} = { 'name' => $assignee };
    }
    # $jira_hash{'parent'}
    if ($json_hash->{'parent'}) {
        $jira_hash{'parent'} = { 'key' => $json_hash->{'parent'} };
    }
    # $jira_hash{'epic_link'}
    # NOTE: Sub-task tickets inherit the epic link from their parent task
    if ($epic_link && ($jira_hash{issuetype}->{name} ne 'Sub-task')) {
        $jira_hash{EPIC_LINK_CUSTOM_FIELD_ID()} = $epic_link;
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
                    'fixVersions' => [{ 'name' => 'Ensembl 99' }],
                    'issuetype'   => { 'name' => 'Task' },
                    'description' => 'Example for Bio::EnsEMBL::Compara::Utils::JIRA',
                    'labels'      => ['Example'],
                    'summary'     => 'Example task'
                };
                my $ticket_key = $jira_adaptor->_create_new_ticket($ticket, 0);
  Description : Creates the JIRA ticket and returns its JIRA key
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
        $ticket_key = $new_ticket->{key};
    }
    $self->{_logger}->info(sprintf("Done. Key assigned: %s\n", $ticket_key));
    return $ticket_key;
}

=head2 _update_ticket

  Arg[1]      : string $ticket_key - key of the JIRA ticket to be updated
  Arg[2]      : string $description - new description to assign to the ticket
  Arg[3]      : int $dry_run - in dry-run mode, the JIRA ticket will not be
                updated
  Example     : $jira_adaptor->_update_ticket('ENSCOMPARASW-352', 'New ticket description', 0);
  Description : Reopens the JIRA ticket, updates its content and removes its
                previous assignee (unless in dry-mode)
  Return type : none
  Exceptions  : none

=cut

sub _update_ticket {
    my ( $self, $ticket_key, $description, $dry_run ) = @_;
    $self->{_logger}->info(sprintf('Updating %s ... ', $ticket_key));
    # Get the "Reopen Issue" transition information for this JIRA ticket
    my $url = "https://www.ebi.ac.uk/panda/jira/rest/api/latest/issue/$ticket_key/transitions";
    my $response = $self->_http_request('GET', $url);
    my @reopen_transition = grep { $_->{name} =~ /Reopen Issue/i } @{ $response->{transitions} };
    if (!@reopen_transition) {
        $self->{_logger}->info("Skipped. The ticket is not Resolved or Closed.\n");
    } else {
        if ($dry_run) {
            $self->{_logger}->info("Done. [dry-run ON]\n");
        } else {
            # Reopen the ticket
            my $transition_id = $reopen_transition[0]->{id};
            $self->_http_request('POST', $url, { 'transition' => {'id' => $transition_id} });
            # And update its description and remove the previous assignee
            my $info_to_update = { fields => {
                description => $description,
                assignee    => undef,
            } };
            $self->_put_request('issue', $ticket_key, $info_to_update);
            $self->{_logger}->info("Done.\n");
        }
    }
}

=head2 _post_request

  Arg[1]      : string $action - a POST request's action to perform, i.e.
                'issue' (to create new JIRA tickets), 'search' or 'issueLink'
                (to link JIRA tickets)
  Arg[2]      : hashref $content_data - a POST request's content data
  Example     : my $tickets = $jira_adaptor->_post_request(
                    'search', {'jql' => 'project=ENSCOMPARASW', 'maxResults' => 10});
  Description : Sends a HTTP POST request to the JIRA server and returns the
                response
  Return type : hashref for 'issue'; arrayref for 'search' and 'issueLink'
  Exceptions  : none

=cut

sub _post_request {
    my ( $self, $action, $content_data ) = @_;
    # Check if the action requested is available
    my %available_actions = map { $_ => 1 } qw(issue search issueLink);
    if (! exists $available_actions{$action}) {
        my $action_list = join("\n", sort keys %available_actions);
        $self->{_logger}->error("Unexpected POST request '$action'! Allowed options:\n$action_list", 0, 0);
    }
    # Do the HTTP POST request and get the response for the given $action and $content_data
    my $url = 'https://www.ebi.ac.uk/panda/jira/rest/api/latest/' . $action;
    return $self->_http_request('POST', $url, $content_data);
}

=head2 _put_request

  Arg[1]      : string $action - a PUT request's action to perform, i.e.
                'issue' (to update an existing JIRA ticket)
  Arg[2]      : hashref $content_data - a PUT request's content data
  Example     : my $tickets = $jira_adaptor->_put_request(
                    'issue', 'ENSCOMPARASW-302',
                    {'fields' => {'description' => 'New description'}});
  Description : Sends a HTTP PUT request to the JIRA server
  Return type : none
  Exceptions  : none

=cut

sub _put_request {
    my ( $self, $action, $ticket_key, $content_data ) = @_;
    # Check if the action requested is available
    my %available_actions = map { $_ => 1 } qw(issue);
    if (! exists $available_actions{$action}) {
        my $action_list = join("\n", sort keys %available_actions);
        $self->{_logger}->error("Unexpected PUT request '$action'! Allowed options:\n$action_list", 0, 0);
    }
    # Do the HTTP PUT request
    my $url = 'https://www.ebi.ac.uk/panda/jira/rest/api/latest/' . $action . '/' . $ticket_key;
    $self->_http_request('PUT', $url, $content_data);
}

=head2 _http_request

  Arg[1]      : string $method - request method, e.g. POST
  Arg[2]      : string $url - URL to do the request to
  Arg[3]      : (optional) hashref $content_data - a request's content data
  Example     : my $response = $jira_adaptor->_http_request(
                    'POST', 'https://www.ebi.ac.uk/panda/jira/rest/api/latest/issue',
                    {'jql' => 'project=ENSCOMPARASW', 'maxResults' => 10});
  Description : Sends a request to the JIRA server and returns the decoded response
  Return type : arrayref or hashref (depending on $method and $url)
  Exceptions  : none

=cut

sub _http_request {
    my ( $self, $method, $url, $content_data ) = @_;
    $content_data //= {};
    # Create the HTTP request and LWP objects to get the response for the given arguments
    $self->{_logger}->debug("$method Request on $url\n");
    my $request;
    if ( $self->{_auth_token} ) {
        my $header = ['Authorization' => "Basic " . $self->{_auth_token}, 'Content-Type' => 'application/json'];
        $request = HTTP::Request->new($method, $url, $header);
    } else {
        my $header = ['Content-Type' => 'application/json'];
        $request = HTTP::Request->new($method, $url, $header);
        $request->authorization_basic($self->{_user}, $self->{_password});
    }
    my $json_content = encode_json($content_data);
    $request->content($json_content);
    my $agent    = LWP::UserAgent->new();
    my $response = $agent->request($request);
    # Check and report possible errors
    if ($response->code() == 401) {
        $self->{_logger}->error('Incorrect JIRA password. Please, try again.', 0, 0);
    } elsif ($response->code() == 403) {
        my $identity = $self->{_auth_token}
                        ? sprintf("Token '%s'", $self->{_auth_token})
                        : sprintf("User '%s'", $self->{_user});
        $self->{_logger}->error("$identity unauthorised to handle JIRA tickets programmatically", 0, 0);
    } elsif ($response->code() == 405) {
        $self->{_logger}->error("HTTP method '$method' not allowed", 0, 0);
    } elsif (! $response->is_success()) {
        $self->{_logger}->error($response->as_string(), 0, 0);
    }
    # Return the response content
    return [] unless $response->content();
    return decode_json($response->content());
}

1;
