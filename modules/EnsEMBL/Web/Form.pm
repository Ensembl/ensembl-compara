=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Form;

use strict;

## TODO - remove backward compatibility patches when ok to remove

################## Structure of form ###################
##  <form>                                            ##
##  <h2>HEADING</h2><!--single-->                     ##
##  <div>HEAD NOTES</div><!--multiple-->              ##
##  <fieldset>ALL ELEMENTS</fieldset><!--multiple-->  ##
##  <div>FOOT NOTES</div><!--multiple-->              ##
##  </form>                                           ##
########################################################

use base qw(EnsEMBL::Web::DOM::Node::Element::Form);

use EnsEMBL::Web::Form::Element;

use constant {

  CSS_CLASS_DEFAULT       => 'std',
  CSS_CLASS_VALIDATION    => 'check _check',

  HEADING_TAG             => 'h2',
  CSS_CLASS_HEADING       => '',
  NOTES_HEADING_TAG       => 'h3',
  CSS_NOTES_MESSAGE_PAD   => 'message-pad',
  CSS_CLASS_NOTES         => 'info',
  
  _FLAG_HEAD_NOTE         => 'is_head_note',
  _FLAG_FOOT_NOTE         => 'is_foot_note',
};

sub new {
  ## @overrides
  ## Creates a new DOM::Node::Element::Form and adds the required attributes before returning it
  ## @param HashRef with keys that get added as attributes, plus some extra keys as below (these don't get added as attributes)
  ##  - skip_validation   Flag if on, no validation is done on JS end
  ##  - dom               DOM object (optional)
  ##  - format            Output format - if format is anything other than HTML, the form will not be printed
  my $class = shift;
  my $params = shift;

  ##compatibility patch
  if (ref($params) ne 'HASH') {
    return $class->_new($params, @_);
  }
  ##compatibility patch ends

  my $self = $class->SUPER::new(delete $params->{'dom'});

  $self->{'_format'}    = delete $params->{'format'} || 'HTML';
  $params->{'method'} ||= 'post';
  $params->{'class'}  ||= $self->CSS_CLASS_DEFAULT;

  # add attributes
  $self->set_attribute('class', $self->CSS_CLASS_VALIDATION) unless delete $params->{'skip_validation'};
  $self->set_attribute($_, $params->{$_}) for keys %$params;

  $self->dom->map_element_class ({                            #map all form components to classes for DOM
    'form-fieldset'    => 'EnsEMBL::Web::Form::Fieldset',
    'form-field'       => 'EnsEMBL::Web::Form::Field',
    'form-matrix'      => 'EnsEMBL::Web::Form::Matrix',
  });

  EnsEMBL::Web::Form::Element->map_element_class($self->dom); #map all elements to classes for DOM

  return $self;
}

sub render {
  ## @overrides
  ## Modifies the form before calling the inherited render method  
  my $self = shift;
  return $self->format eq 'HTML' ? $self->SUPER::render(@_) : '';  #dont return any form stuff if the format is not HTML (webpage) (eg: csv)
}

sub fieldsets {
  ## @return all fieldset elements added to the form
  my $self = shift;
  my $fieldsets = [];
  for (@{$self->child_nodes}) {
    push @$fieldsets, $_ if $_->node_name eq 'fieldset';
  }
  return $fieldsets;
}

sub foot_notes {
  ## @return Gets all the footnotes (Element::Div objects) added to the form
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_FOOT_NOTE);
}

sub head_notes {
  ## @return Gets all the headnotes (Element::Div objects) added to the form
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_HEAD_NOTE);
}

sub fieldset {
  ## Gets last fieldset added to the form OR if none added yet, adds a new one and returns it
  ## @return Form::Fieldset object
  my $self = shift;
  my $fieldsets = $self->fieldsets;
  return scalar @$fieldsets ? $fieldsets->[-1] : $self->add_fieldset;
}

sub add_fieldset {
  ## Adds a fieldset to the form
  ## @param String with Legend text or HashRef with following keys (plus any other node attributes to be set on the fieldset object)
  ##  - legend            Legend string
  ##  - stripes           Shows the fieldset child nodes in alternative bg colour
  ##  - no_required_notes Flag if on will not print a note about the required fields
  ## @return Form::Fieldset object
  my $self      = shift;
  my $fieldset  = $self->dom->create_element('form-fieldset');
  if (@_) {
    my $attribs = ref $_[0] eq 'HASH' ? $_[0] : {'legend' => $_[0]};
    my $options = { map {$_ => delete $attribs->{$_}} qw(legend stripes no_required_notes) };
    $fieldset->configure($options)      if keys %$options;
    $fieldset->set_attributes($attribs) if keys %$attribs;
  }

  my $foot_notes = $self->foot_notes;
  return scalar @$foot_notes ? $self->insert_before($fieldset, $foot_notes->[0]) : $self->append_child($fieldset);
}

sub has_fieldset {
  ## Check if the form has any fieldset added
  my $self = shift;
  return scalar @{$self->get_elements_by_tag_name('fieldset')} ? 1 : 0;
}

sub heading {
  ## Gets existing or modifies existing or adds new heading at the top of the form
  ## @param Heading text (is not escaped before adding)
  ## @return DOM::Node::Element::H? object
  my $self    = shift;
  my $heading = $self->first_child && $self->first_child->node_name eq $self->HEADING_TAG ? $self->first_child : $self->prepend_child($self->HEADING_TAG);
  $heading->inner_HTML(shift) if @_;
  return $heading;
}

sub add_notes {
  ## Adds notes to the form (or fieldset)
  ## If 'location' and 'heading' key is missing, appends the notes to the last fieldset (see fieldset->add_notes)
  ## @param Either a string that needs to go in the notes, OR a HashRef with the following keys
  ##  - id        Id if any for the notes div
  ##  - location  (head|foot) or head by default
  ##  - class     css class name to override the default class
  ##  - heading   heading text, goes inside the <$self->NOTES_HEADING_TAG>
  ##  - text      Text displayed inside <div>
  ##  - list      Text to be displayed in list (<ul> or <ol>)
  ##  - serialise In case of list, <ol> is used if this flag is on, otherwise <ul>
  ## @return DOM::Node::Element::Div object
  my ($self, $params) = @_;
  
  ## If only text provided
  $params = {'text' => $params} unless ref $params eq 'HASH';

  ## if no location or heading, add notes to fieldset
  $params->{'location'} = 'head' if exists $params->{'heading'};
  return $self->fieldset->add_notes($params) unless exists $params->{'location'};

  my $notes = $self->dom->create_element('div', {
    'flags' => $params->{'location'} eq 'foot' ? $self->_FLAG_FOOT_NOTE : $self->_FLAG_HEAD_NOTE,
    'class' => $params->{'class'} || $self->CSS_CLASS_NOTES,
    (exists $params->{'id'} ? ('id' => $params->{'id'}) : ()),
  });

  $notes->append_child({
    'node_name'   => $self->NOTES_HEADING_TAG,
    'inner_HTML'  => $params->{'heading'}
  }) if exists $params->{'heading'};

  if (exists $params->{'text'}) {
    my $text = $params->{'text'};
    $text    = $self->dom->create_element('p', {'inner_HTML' => $text})->render if $text !~ /^[\s\t\n]*\<(p|div|table|form|pre|ul)(\s|\>)/;
    $notes->append_child({
      'node_name'   => 'div',
      'class'       => $self->CSS_NOTES_MESSAGE_PAD,
      'inner_HTML'  => $text
    });
  }

  $notes->append_child({
    'node_name'   => $params->{'serialise'} ? 'ol' : 'ul',
    'children'    => [ map {'node_name' => 'li', 'inner_HTML' => $_}, @{$params->{'list'}}]
  }) if exists $params->{'list'};
  
  # if head notes
  if ($params->{'location'} eq 'head') {
    return $self->insert_before($notes, $_) for @{$self->fieldsets};  # insert head note before first fieldset
    return $self->insert_before($notes, $_) for @{$self->foot_notes}; # insert head note before foot note if no fieldset found
  }

  # if foot notes, or if head notes but nothing added to the form yet
  return $self->append_child($notes);
}

sub force_reload_on_submit {
  ## Adds an empty element in the form which directs JS to refresh the page once modal popup is closed
  ## Works only with the popup modal form
  my ($self, $url) = @_;
  my $modal_reload = $self->fieldset->append_child($self->dom->create_element($url ? 'a' : 'div'));
  $modal_reload->set_attribute('class', 'modal_reload hidden');
  $modal_reload->set_attribute('href',  $url) if $url;
  return 1;
}

## Addition of new form elements is always done to last fieldset.
sub add_field   { shift->fieldset->add_field(@_);   }
sub add_hidden  { shift->fieldset->add_hidden(@_);  }
sub add_matrix  { shift->fieldset->add_matrix(@_);  }
sub add_button  { shift->fieldset->add_button(@_);  }
sub add_element { shift->fieldset->add_element(@_); }

sub format      { shift->{'_format'};               }


##################################
##                              ##
## BACKWARD COMPATIBILITY PATCH ##
##                              ##
##################################
use Carp qw(carp);
my $do_warn = 1;
sub _new {
  my ($class, $name, $action, $method, $style) = @_;

  carp('Constructor for form is modified. Use $self->new_form if this module is inherited from EnsEMBL::Web::Component, or pass arguments as hash. See EnsEMBL::Web::Form for more details -') if $do_warn;
  
  return $class->new({
    'id'        => $name,
    'action'    => $action,
    'method'    => $method,
    'class'     => $style
  });
}

1;
