package EnsEMBL::Web::Wizard;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);
#use Text::Aspell;
use EnsEMBL::Web::File::Text;

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);


sub new {
  my ($class, $object) = @_;
  my $self = {'_nodes' => {}, '_access_level' => ''};
  bless $self, $class;
  my $init = $class.'::_init';
  if ($self->can($init)) { 
    my ($data, $fields, $node_defs, $messages, $karyotype) = @{ $self->$init($object) };
    $self->{'_data'}        = $data;
    $self->{'_fields'}      = $fields;
    $self->{'_node_defs'}   = $node_defs;
    $self->{'_messages'}    = $messages;
  }
  return $self;
}


sub data { 
  my ($self, $name, $value) = @_;
  if ($value) {
    $self->{'_data'}{$name} = $value;
  }
  return $self->{'_data'}{$name}; 
}

sub field {
  my ($self, $field, $param, $value) = @_;
  if ($value) {
    $self->{'_fields'}{$field}{$param} = $value;
  }
  return $self->{'_fields'}{$field}{$param}; 
}

sub redefine_node {
  my ($self, $node, $attrib, $value) = @_;
  if (ref($self->{'_node_defs'}{$node}{$attrib}) eq 'ARRAY') {
    push(@{$self->{'_node_defs'}{$node}{$attrib}}, @$value) 
      unless grep {$_ eq $value} @{$self->{'_node_defs'}{$node}{$attrib}};
  }
  else {
    $self->{'_node_defs'}{$node}{$attrib} = $value;
  }
}

sub get_fields    { return $_[0]->{'_fields'}; }
sub get_node_def  { return $_[0]->{'_node_defs'}{$_[1]}; }
sub get_message   { return $_[0]->{'_messages'}{$_[1]}; }

sub access_level {
  my ($self, $level) = @_;
  if ($level) {
    $self->{'_access_level'} = $level;
  }
  return $self->{'_access_level'};
}

## 'FLOWCHART' FUNCTIONS

sub add_nodes {
  my ($self, $nodes) = @_;
  foreach my $node (@$nodes) {
    $self->{'_nodes'}{$node} = $self->get_node_def($node);
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
  my ($self, $object, $new_node) = @_;
  my $node;

  ## are we resetting the current node?
  if ($new_node) {
    $object->param('node', $new_node);
    return $new_node;
  }

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

sub isa_node {
  my ($self, $node) = @_;
  return $self->{'_nodes'}{$node};
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

sub chain_nodes {
  my ($self, $edge_ref) = @_;
  foreach my $edge (@$edge_ref) {
    my $start = $$edge[0];
    my $end = $$edge[1];
    push(@{$self->{'_nodes'}{$start}{'_outgoing_edges'}}, $end);
    push(@{$self->{'_nodes'}{$end}{'_incoming_edges'}}, $start);
  }
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

sub add_incoming_edges {
  my ($self, $edge_ref) = @_;
  foreach my $edge (@$edge_ref) {
    my $start = $$edge[0];
    my $end = $$edge[1];
    push(@{$self->{'_nodes'}{$start}{'_incoming_edges'}}, $end);
  }
}

sub remove_incoming_edge {
  my ($self, $start, $end) = @_;
  my $edge_ref = $self->{'_nodes'}{$start}{'_incoming_edges'};
  my $edges = scalar(@$edge_ref);
  for (my $i=0; $i<$edges; $i++) {
    my $edge = @{$edge_ref}[$i];
    splice(@{$edge_ref}, $i) if $edge eq $end;
  }
}

sub get_incoming_edges {
  my ($self, $node) = @_;
  ## this function seems to returning duplicate values, so weed them out!
  my (%check_hash, @edges);
  foreach my $edge (@{$self->{'_nodes'}{$node}{'_incoming_edges'}}) {
    $check_hash{$edge}++;
    push @edges, $edge if $check_hash{$edge} < 2;
  }
  return \@edges;
}

sub node_restriction {
  my ($self, $node, $value) = @_;
  if ($value) {
    $self->{'_nodes'}{$node}{'restricted'} = $value;
  }
  return $self->{'_nodes'}{$node}{'restricted'};
}

sub lock_all_nodes {
  my $self = shift;
  my $value = shift || 1;
  foreach my $node (@{$self->{'_nodes'}}) {
    $self->{'_nodes'}{$node}{'_restricted'} = $value;
  }
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
  my %form_fields = %{$self->get_fields};

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

  ## don't pass data if returning via a Back button
  if ($object->param) {
    foreach my $param ($object->param) {
      return if ($param =~ /^submit/ && $object->param($param) =~ /Back/);
    }
  } 

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

  ## make lookup of fields you don't want to pass as hidden
  my $edges = $self->get_incoming_edges($node);
  my @matches = grep { $node } @$edges;
  my @no_pass;
  if (scalar(@matches) < 1) {
    @no_pass = $self->{'_nodes'}{$node}{'no_passback'};
  }
  my $widgets = $self->{'_nodes'}{$node}{'input_fields'};
  push @no_pass, @$widgets if $widgets;

  ## put values into a hash to get around Perl's crap array functions!
  my %skip;
  foreach my $x (@no_pass) {
    $skip{$x}++;
  } 
  
  foreach my $field (@fields) {
    next if $field =~ /submit/;  
    next if $field =~ /feedback/;  
    next if exists( $skip{$field} );
  
    ## don't pass 'previous' field or it screws up back buttons!  
    next if $field =~ /previous/;

    ## include a hidden element for passing data
    my @values = $object->param($field); ## use array context to catch multiple values
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
  my %form_fields = %{$self->get_fields};
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
      'type'          => $field_info{'type'},
      'name'          => $field_name,
      'label'         => $field_info{'label'},
      'required'      => $field_info{'required'},
      'rows'          => $field_info{'rows'},
      'notes'         => $field_info{'notes'},
      'select'        => $field_info{'select'},
      'string_name'   => $field_info{'string_name'},
      'string_label'  => $field_info{'string_label'},
    );

    ## extra parameters for multi-value fields
    if ($field_info{'type'} eq 'DropDown' || $field_info{'type'} eq 'DropDownAndString'
          || $field_info{'type'} eq 'MultiSelect') {
      if ($object->param($field_name)) {
        $parameter{'value'}  = [$object->param($field_name)]; 
      }
      else {
        $parameter{'value'}  =  $self->{'_data'}{'record'}{$field_name} 
                                || $field_info{'value'};
      }
      $parameter{'values'} = $self->{'_data'}{$field_info{'values'}};
      $parameter{'select'} = $field_info{'select'};
      if ($field_info{'type'} eq 'DropDownAndString') {
        my $string = $parameter{'string_name'};
        if ($object->param($string)) {
          $parameter{'string_value'}  = [$object->param($string)]; 
        }
        else {
          $parameter{'string_value'}  =  $self->{'_data'}{'record'}{$string} 
                                || $field_info{'string_value'};
        }
      }
    }
    elsif ($field_info{'type'} eq 'CheckBox') {
      $parameter{'value'}  =  $field_info{'value'} || 'yes';
      if ($object->param($field_name) 
          || $self->{'_data'}{'record'}{$field_name} =~ /^(yes|Y|on)$/) {
        $parameter{'checked'} = 1;
      }
    }
    else {
      my @values = $object->param($field_name);
      if (scalar(@values) > 1) {
        my $unique = _uniquify(\@values);
        $parameter{'value'} = $unique;
      }
      else {
        $parameter{'value'} = $object->param($field_name) 
                              || $self->{'_data'}{'record'}{$field_name} 
                              || $field_info{'value'};
        if (!$parameter{'value'} && ($field_info{'type'} eq 'Int' || $field_info{'type'} eq 'NonNegInt')) {
          $parameter{'value'} = '0';
        }
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

  my $back = $self->{'_nodes'}{$node}{'back'};
warn "Back: $back";
  if ($back) {
    ## normally limit back button to direct incoming edges
    my $back_node;
    if ($back eq '1') {
      my $previous = $object->param('previous');
      my @incoming = @{ $self->get_incoming_edges($node) };
warn "Incoming!! @incoming";
      foreach my $edge (@incoming) {
        $back_node = $edge;
        last if $edge eq $previous; ## defaults to last incoming edge
      }
    }
    ## unless the return node is specified (e.g. to skip a decision node)
    else {
      $back_node = $back;
    }
    $form->add_element(
      'type'  => 'Submit',
      'name'  => "submit_$back_node",
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

  my %form_fields = %{$self->get_fields};
  my @params = $object->param;
  foreach my $param (@params) {
    next unless $form_fields{$param}; ## skip submit buttons, etc
    my %field_info = %{$form_fields{$param}};
    my $value;
    if ($field_info{'type'} eq 'MultiSelect') {
      $value = [$object->param($param)];
    }
    else { 
      $value = $object->param($param);
    }
    $record{$param} = $value;
  }
  return \%record;
}

sub spellcheck {
  my ($self, $object, $text) = @_;

  my $aspell_cmd = 'aspell';
  my $aspell_opts = "-a --lang=en_US"; 
  my $ensembl_dict = $object->species_defs->ENSEMBL_SERVERROOT.'/utils/ensembl.aspell';
  $aspell_opts .= " --personal=$ensembl_dict"; 

  my $timestamp = time();
  my $filename .= 'spell_'.$timestamp;
  my $cache = new EnsEMBL::Web::File::Text($object->[1]->{'_species_defs'});
  $cache->set_cache_filename($filename);
  my $result = $cache->save_aspell($object, $text);

  ## do spell check
  my $checked = '<strong>** CHECKED TEXT **</strong><br />';
  if ($result) { 
    my $i = 0;
    my $cachefile = $cache->filename;
    my @lines = split( /\n/, $text );
    my $cmd = "$aspell_cmd $aspell_opts < $cachefile 2>&1";
    open ASPELL, "$cmd |";
    # parse each line of aspell return
    for my $result ( <ASPELL> ) {
      chomp( $result );
      # if '&', then not in dictionary but has suggestions
      # if '#', then not in dictionary and no suggestions
      # if '*', then it is a delimiter between text inputs
      #if( $result =~ /^\*/ ) { ## no errors found
      #  $checked .= $lines[$i];
      #}
      #elsif( $result =~ /^(&|#)/ ) {
      #  my @array = split(' ', $result);
      $checked .= $result;
    }
  }
  return $checked;
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
