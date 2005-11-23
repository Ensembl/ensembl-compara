package EnsEMBL::Web::Wizard;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);


sub new {
  my $class = shift;
  my $self = {'_nodes' => {}};
  bless $self, $class;
  return $self;
}

## 'FLOWCHART' FUNCTIONS

sub add_nodes {
  my ($self, $nodes) = @_;
  foreach my $node (@$nodes) {
    $self->{'_nodes'}{$node} = $self->get_node($node);
  }
}


sub default_node {
  my ($self, $default) = @_;
  if ($default) {
    ## unset any existing default
    foreach my $node (keys %{$self->{'_nodes'}}) {
      if ($self->{'_nodes'}{$node}{'default'}) {
        $self->{'_nodes'}{$node}{'default'} = 0;
      }
    }
    ## set new default
    $self->{'_nodes'}{$default}{'default'} = 1;
  }
  else {
    foreach my $node (keys %{$self->{'_nodes'}}) {
      if ($self->{'_nodes'}{$node}{'default'}) {
        $default = $node;
        last;
      }
    }
  }
  return $default;
}

sub current_node {
  my ($self, $object) = @_;
  my $node;

  ## check if we have a submit button setting the next node
  my @params = $object->param();
  foreach my $param (@params) {
    if ($param =~ m/submit_/) {
      ($node = $param) =~ s/submit_//g;
      last;
    }
  }
  if (!$node) { ## if no submit, try other options
    $node = $object->param('node') || $self->default_node;
  }
  return $node;
}

sub isa_page {
  my ($self, $node) = @_;
  return $self->{'_nodes'}{$node}{'page'};
}

sub isa_form {
  my ($self, $node) = @_;
  my $form = 0;
  if ($self->{'_nodes'}{$node}{'input_fields'} || $self->{'_nodes'}{$node}{'show_fields'}) {
    $form = 1;
  }
  return $form;
}

sub add_outgoing_edges {
  my ($self, $edge_ref) = @_;
  foreach my $edge (@$edge_ref) {
    my $source = $$edge[0];
    my $target = $$edge[1];
    push(@{$self->{'_nodes'}{$source}{'_outgoing_edges'}}, $target);
  }
}

sub get_outgoing_edges {
  my ($self, $node) = @_;
  ## this function seems to returning duplicate values, so weed them out!
  my %check_hash;
  foreach my $edge (@{$self->{'_nodes'}{$node}{'_outgoing_edges'}}) {
    $check_hash{$edge}++;
  }
  my @edges = keys %check_hash; 
  return \@edges;
}

##---------------- FORM ASSEMBLY FUNCTIONS --------------------------------

sub show_fields {
  my ($self, $node, $form, $object) = @_;

  my @fields = @{ $self->{'_nodes'}{$node}{'show_fields'} };
  my %form_fields = $self->form_fields;

  $form->add_element( 'type' => 'SubHeader', 'value' => 'Please check your input');
                                                                                
  foreach my $field (@fields) {
    my %field_info = %{$form_fields{$field}};
    ## show the input to the user (masking passwords for security)
    my $value = $field_info{'type'} eq 'Password' 
                    ? '******' : $object->param($field);
    $form->add_element(
      'type'      => 'Information',
      'label'     => $field_info{'label'},
      'value'     => $value,
    );
    ## include a hidden element for passing data
    $form->add_element(
      'type'      => 'Hidden',
      'name'      => $field,
      'value'     => $object->param($field),
    );
  }

}

sub add_widgets {
  my ($self, $node, $form, $object) = @_;

  my @inputs = @{ $self->{'_nodes'}{$node}{'input_fields'} };
  my %form_fields = $self->form_fields;
                                                                                
  foreach my $field (@inputs) {
    my %field_info = %{$form_fields{$field}};
    $form->add_element(
      'type'      => $field_info{'type'},
      'name'      => $field,
      'label'     => $field_info{'label'},
      'required'  => $field_info{'required'},
      'value'     => $object->param($field),
    );
  }

}

sub add_buttons {
  my ($self, $node, $form, $object) = @_;

  $form->add_element(
    'type'  => 'Hidden',
    'name'  => 'previous',
    'value' => $node,
  );

  if ($self->{'_nodes'}{$node}{'back'}) {
    $form->add_element(
      'type'  => 'Submit',
      'name'  => 'submit_'.$object->param('previous'),
      'value' => '< Back',
      'spanning' => 'inline',
    );
  }

  my @edges = @{ $self->get_outgoing_edges($node) };
  my $edge_count = scalar(@edges);
  warn "$edge_count outgoing edges";
  foreach my $edge (@edges) {
    warn "Adding button from edge $edge";
    my $text = $self->{'_nodes'}{$edge}{'button'} || 'Next';
    $form->add_element(
      'type'  => 'Submit',
      'name'  => 'submit_'.$edge,
      'value' => $text.' >',
      'spanning' => 'inline',
    );
  }

}
                                                                                
__END__
                                                                                
=head1 Ensembl::Web::Wizard

=head2 SYNOPSIS

Abstract class - see child objects for details of use.

=head2 DESCRIPTION

Parent class for Wizard objects. A child named after the data type manipulated by the Wizard is needed in order to configure the properties of specific nodes.

=head2 METHOD 

=head3 B<new>
                                                                                
Description: Simple constructor method

=head3 B<add_nodes>
                                                                                
Description: Adds one or more available nodes to a Wizard object

Arguments: a reference to an array of node names
                                                                                
Returns:  none

=head3 B<default_node>
                                                                                
Description: Get/set accessor method for the nodes of a wizard flowchart. If given a node name, it sets that as the default node; if not, it looks up the default

Arguments: node name (string) - optional
                                                                                
Returns: node name (string) 

=head3 B<current_node>
                                                                                
Description: Returns the name of the current node, using URL parameters in the first instance, and falling back to the default node if no node parameter is available

Arguments: a reference to a data object (from which to retrieve the URL parameters)
                                                                                
Returns: node name (string)

=head3 B<isa_page>
                                                                                
Description: Checks if the given node is supposed to output a web page

Arguments: node name (string)
                                                                                
Returns: Boolean

=head3 B<isa_form>
                                                                                
Description: Checks if the given node is supposed to create a form object

Arguments: node name (string)    
                                                                                
Returns: Boolean

=head3 B<add_outgoing_edges>
                                                                                
Description: Adds uni-directional links between pairs of nodes in a wizard flowchart

Arguments: a reference to an array of arrays - each subarray consists of the name of the start node and the name of the end node
                                                                                
Returns: none

=head3 B<get_outgoing_edges>
                                                                                
Description: Fetches a list of all exit points for a given node

Arguments: node name (string)  
                                                                                
Returns: an array of node names

=head3 B<show_fields>
                                                                                
Description: A wrapper for uncomplicated forms, which displays the user input and adds hidden fields to the form object so that the parameters can be passed along. [More complex forms can be built, one widget at a time, within the child module, if preferred.]

Arguments: node name (string), EnsEMBL::Web::Form object, data object    
                                                                                
Returns: none

=head3 B<add_widgets>
                                                                                
Description: A wrapper for uncomplicated forms, which takes the list of required fields and adds each one to the form object. [More complex forms can be built, one widget at a time, within the child module, if preferred.]

Arguments:  node name (string), EnsEMBL::Web::Form object, data object       
                                                                                
Returns: none

=head3 B<add_buttons>
                                                                                
Description: A wrapper which adds buttons for incoming and outgoing edges, based on the definitions for each node. It is recommended that this method is used instead of 'manually' adding each submit button.

Arguments:  node name (string), EnsEMBL::Web::Form object, data object       
                                                                                
Returns: none

=head2 BUGS AND LIMITATIONS

=head3 Bugs

There is some kind of bug on the setting and getting of edges, whereby a duplicate edge is sometimes returned. A workaround has been placed in get_outgoing_edges to eliminate these duplicates on retrieval, so they are not rendered.

=head3 Limitations

Currently only implements passing of data between nodes via HTML forms (e.g. using hidden fields).

add_widgets only implemented for simple single-value elements, e.g. String, Integer
                                                                                
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut                                                                  

                                                                                
1;
