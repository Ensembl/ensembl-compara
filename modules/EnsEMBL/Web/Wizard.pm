package EnsEMBL::Web::Wizard;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);


sub new {
  my ($class, $object) = @_;
  my $self = {'_nodes' => {}};
  bless $self, $class;
  my $init = $class.'::_init';
  if ($self->can($init)) { 
    my $data = $self->$init($object);
    $self->{'_data'} = $data;
  }
  return $self;
}

sub attrib { 
  my ($self, $name, $value) = @_;
  if ($value) {
    $self->{'_data'}{$name} = $value;
  }
  return $self->{'_data'}{$name}; 
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

sub node_value {
  my ($self, $node, $key, $value) = @_;
  if ($value) {
    $self->{'_nodes'}{$node}{$key} = $value;
  }
  $value = $self->{'_nodes'}{$node}{$key};
  return $value;
}

sub isa_page {
  my ($self, $node) = @_;
  my $page = $self->{'_nodes'}{$node}{'form'} || $self->{'_nodes'}{$node}{'page'};
  return $page;
}

sub isa_form {
  my ($self, $node) = @_;
  return $self->{'_nodes'}{$node}{'form'};
}

sub add_outgoing_edges {
  my ($self, $edge_ref) = @_;
  foreach my $edge (@$edge_ref) {
    my $start = $$edge[0];
    my $end = $$edge[1];
    push(@{$self->{'_nodes'}{$start}{'_outgoing_edges'}}, $end);
  }
}

sub remove_outgoing_edge {
  my ($self, $start, $end) = @_;
  my $edge_ref = $self->{'_nodes'}{$start}{'_outgoing_edges'};
  my $edges = scalar(@$edge_ref);
  for (my $i=0; $i<$edges; $i++) {
    my $edge = @{$edge_ref}[$i];
    splice(@{$edge_ref}, $i) if $edge eq $end;
  }
}

sub get_outgoing_edges {
  my ($self, $node) = @_;
  ## this function seems to returning duplicate values, so weed them out!
  my (%check_hash, @edges);
  foreach my $edge (@{$self->{'_nodes'}{$node}{'_outgoing_edges'}}) {
    $check_hash{$edge}++;
    push @edges, $edge if $check_hash{$edge} < 2;
  }
  return \@edges;
}

##---------------- FORM ASSEMBLY FUNCTIONS --------------------------------

sub simple_form {
  my ($self, $node, $form, $object, $display) = @_;

  $self->add_title($node, $form);
  if ($display eq 'input') { 
    $self->add_widgets($node, $form, $object);
  }
  elsif ($display eq 'output') { 
    $self->show_fields($node, $form, $object);
    $self->pass_fields($node, $form, $object);
  }
  $self->add_buttons($node, $form, $object);
}

sub add_title {
  my ($self, $node, $form) = @_;

  my $title = $self->{'_nodes'}{$node}{'title'};

  $form->add_element( 
    'type' => 'Header', 
    'value' => $title,
  );                                                                            
}

sub show_fields {
  my ($self, $node, $form, $object, $fields) = @_;

  if (!$fields) {
    $fields = $self->{'_nodes'}{$node}{'show_fields'} || $self->default_order;
  } 
  my %form_fields = $self->form_fields;

  foreach my $field (@$fields) {
    my %field_info = %{$form_fields{$field}};
    ## show the input to the user
    my %parameter = (
      'type'      => 'NoEdit',
      'label'     => $field_info{'label'},
    );
    
    my ($output, @values);
    if ($field_info{'type'} eq 'DropDown' || $field_info{'type'} eq 'MultiSelect') { ## look up 'visible' value(s) of multi-value fields
      @values = $object->param($field) || $self->{'_data'}{'record'}{$field};
      my ($lookup, $count);
      foreach my $value (@values) {
        foreach my $element (@{$self->{'_data'}{$field_info{'values'}}}) {
          if ($$element{'value'} eq $value) {
            $lookup = $$element{'name'};
            last;
          }
        }
        $output .= ', ' if $count > 0;
        $output .= $lookup;
        $count++;
      }
    }
    elsif ($field_info{'type'} eq 'Password') { ## mask passwords
      $output = '******';
    }
    else {
      my $text = $object->param($field) || $self->{'_data'}{'record'}{$field};
      if (!$text && ($field_info{'type'} eq 'Int' || $field_info{'type'} eq 'NonNegInt')) {
        $text = '0';
      }
      $output = _HTMLize($text);
    }
    $parameter{'value'} = $output;
    $form->add_element(%parameter);
  }

}

sub _uniquify {
  my $a_ref = shift;
  my %unique;
  foreach my $value (@$a_ref) {
    $unique{$value}++;
  }
  my @uniques = (keys %unique);
  return \@uniques;
}

sub _HTMLize {
  my $string = shift;
  $string =~ s/"/&quot;/g;
  return $string;
}

sub pass_fields {
  my ($self, $node, $form, $object, $fields) = @_;

  my @fields;
  if ($fields) {
    @fields = @$fields;
  }
  elsif ($self->{'_nodes'}{$node}{'pass_fields'}) {
    @fields = @{$self->{'_nodes'}{$node}{'pass_fields'}};
  }
  else {
    @fields = $object->param;
  } 

  foreach my $field (@fields) {
    next if $field =~ /submit/;  

    ## don't pass 'previous' field or it screws up back buttons!  
    next if $field =~ /previous/;    

    ## Debug form fields
    #$form->add_element(
    #  'type'      => 'NoEdit',
    #  'label'     => $field,
    #  'value'     => $object->param($field),
    #);

    ## include a hidden element for passing data
    my @values = $object->param($field);
    if (scalar(@values) > 1) {
      my $unique = _uniquify(\@values);
      foreach my $element (@$unique) {
        next unless $element;
        $form->add_element(
          'type'      => 'Hidden',
          'name'      => $field,
          'value'     => $element,
        );
      }
    }
    else {
      next unless $field;
      $form->add_element(
        'type'      => 'Hidden',
        'name'      => $field,
        'value'     => $object->param($field),
      );
    }
  }
}

sub add_widgets {
  my ($self, $node, $form, $object, $fields) = @_;

  if (!$fields) {
    $fields = $self->{'_nodes'}{$node}{'input_fields'} || $self->default_order;
  } 
  my %form_fields = $self->form_fields;
  foreach my $field (@$fields) {
    my %field_info = %{$form_fields{$field}};
    my $field_name = $field;
    ## Is this field involved in looping through multiple records?
    if ($field_info{'loop'}) {
      my $count = $self->{'_data'}{'loops'};
      $field_name .= "_$count"; 
    }

    ## set basic parameters
    my %parameter = (
      'type'      => $field_info{'type'},
      'name'      => $field_name,
      'label'     => $field_info{'label'},
      'required'  => $field_info{'required'},
      'rows'      => $field_info{'rows'},
    );

    ## deal with multi-value fields
    my @values = $object->param($field_name);
    if (scalar(@values) > 1) {
      my $unique = _uniquify(\@values);
      $parameter{'value'} = $unique;
    }
    else {
      $parameter{'value'} = $object->param($field_name) 
                              || $self->{'_data'}{'record'}{$field}
                              || $field_info{'value'};
    }

    ## extra parameters for multi-value fields
    if ($field_info{'type'} eq 'DropDown' || $field_info{'type'} eq 'MultiSelect') {
      if ($object->param($field)) {
        $parameter{'value'}  = [$object->param($field)]; 
      }
      else {
        $parameter{'value'}  =  $self->{'_data'}{'record'}{$field} 
                                || $field_info{'value'};
      }
      ## extra parameters for multi-value fields
      $parameter{'values'} = $self->{'_data'}{$field_info{'values'}};
      $parameter{'select'} = $field_info{'select'};
    }
    else {
      $parameter{'value'} = $object->param($field) 
                              || $self->{'_data'}{'record'}{$field} 
                              || $field_info{'value'};
      if (!$parameter{'value'} && ($field_info{'type'} eq 'Int' || $field_info{'type'} eq 'NonNegInt')) {
        $parameter{'value'} = '0';
      }
    }
    $form->add_element(%parameter);
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
    $form->add_element(
      'type'      => 'StaticImage',
      'name'      => 'spacer',
      'src'       => '/img/blank.gif',
      'alt'       => ' ',
      'width'     => 200,
      'height'    => 25,
      'spanning'  => 'inline',
    );
  }

  my @edges = @{ $self->get_outgoing_edges($node) };
  my $edge_count = scalar(@edges);
  foreach my $edge (@edges) {
    my $text = $self->{'_nodes'}{$edge}{'button'} || 'Next';
    $form->add_element(
      'type'  => 'Submit',
      'name'  => 'submit_'.$edge,
      'value' => $text.' >',
      'spanning' => 'inline',
    );
  }

}

sub create_record {
  my ($self, $object) = @_;
  my %record;

  my %form_fields = $self->form_fields;
  my @params = $object->param;
  foreach my $param (@params) {
    next unless $form_fields{$param}; ## skip submit buttons, etc
    my %field_info = %{$form_fields{$param}};
    my $value;
    if ($field_info{'type'} eq 'DropDown' || $field_info{'type'} eq 'MultiSelect') {
      $value = [$object->param($param)];
    }
    else { 
      $value = $object->param($param);
    }
    $record{$param} = $value;
  }
  return \%record;
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

=head3 B<remove_outgoing_edges>
                                                                                
Description: Removes a given uni-directional links between pairs of nodes. Useful for dynamically changing the flow control of a wizard

Arguments: the names of the start and end nodes defining the edge
                                                                                
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
