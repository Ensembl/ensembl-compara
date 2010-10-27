package EnsEMBL::Web::Form::Box;

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

use constant {
  HEADING_TAG           => 'h3',
  CSS_CLASS             => '',
  CSS_CLASS_HEADING     => '',
  CSS_CLASS_HEAD_NOTES  => '',
  CSS_CLASS_FOOT_NOTES  => '',
};

sub set_heading {
  ## Adds a heading Node object to the box
  ## We can have only one heading. Adding a new one removes the previous one.
  ## @params Heading text
  ## @params Flag to tell whether text is html
  ## @return DOM::Node::Element::H? object
  my ($self, $text, $text_is_html) = @_;
    
  $text = '' unless defined $text;
  
  # if no action required
  return undef if $text eq '';

  #get/create heading node
  unless (exists $self->{'__heading'}) {
    $self->{'__heading'} = $self->dom->create_element($self->HEADING_TAG);
    $self->insert_at_beginning($self->{'__heading'});
  }
  
  # if removal intended
  if ($text eq '') {
    $self->remove_child($self->{'__heading'});
    delete $self->{'__heading'};
    return undef;
  }

  #add text
  if ($text_is_html) {
    $self->{'__heading'}->inner_HTML($text);
  }
  else {
    $self->{'__heading'}->inner_text($text);
  }
  $self->{'__heading'}->set_attribute('class', $self->CSS_CLASS_HEADING);
  
  #return node
  return $self->{'__heading'};
}

sub get_heading {
  ## Gets heading
  ## @return DOM::Node::Element::H? object or undef
  my $self = shift;
  return $self->{'__heading'} || undef;
}

sub add_head_notes {
  ## Adds head notes to the Box
  ## @params String or Array of strings to go in the notes
  ## @params Flag to tell whether text is html
  ## @params Flag to tell whether list should be displayed with serial numbers or bullets (1 = <ol>, 0 = <ul>) if list.
  ## @returns DOM::Node::Element::Div object
  return shift->_add_notes('head', @_);
}

sub add_foot_notes {
  ## Adds foot notes to the Box
  ## @params String or Array of strings to go in the notes
  ## @params Flag to tell whether text is html
  ## @params Flag to tell whether list should be displayed with serial numbers or bullets (1 = <ol>, 0 = <ul>)
  ## @returns DOM::Node::Element::Div object
  return shift->_add_notes('foot', @_);
}

sub get_head_notes {
  ## Gets head notes of the Box
  ## @returns DOM::Node::Element::Div object
  my $self = shift;
  return $self->{'__head_notes'} || undef;
}

sub get_foot_notes {
  ## Gets foot notes of the Box
  ## @returns DOM::Node::Element::Div object
  my $self = shift;
  return $self->{'__foot_notes'} || undef;
}

sub _add_notes {
  my ($self, $location, $params) = @_;
  my $text = $params->{'text'} || '';
  my $text_is_html = exists $params->{'text_is_html'} && $params->{'text_is_html'} eq '1' ? 1 : 0;
  my $serialise = exists $params->{'serialise'} && $params->{'serialise'} eq '1' ? 1 : 0;
  
  
  unless ($location =~ /^(head|foot)$/) {
    warn "Invalid location for adding notes";
    return;
  }
  
  my $notes = undef;
  $notes = $self->get_head_notes if $location eq 'head';
  $notes = $self->get_foot_notes if $location eq 'foot';

  unless (defined $notes) {
    $notes = $self->dom->create_element('div');
    
    #append according to specified location
    if ($location eq 'head') {
      my $heading = $self->get_heading;
      $self->insert_after($notes, $heading) if defined $heading;
      $self->insert_at_beginning($notes) unless defined $heading;
    }
    else {
      $self->append_child($notes);
    }

    #css class
    my $css_class = { 'head' => $self->CSS_CLASS_HEAD_NOTES, 'foot' => $self->CSS_CLASS_FOOT_NOTES };
    $notes->set_attribute('class', $css_class->{ $location });
  }
  if (ref($text) eq 'ARRAY') {
    my $list = $self->dom->create_element($serialise ? 'ol' : 'ul');
    for (@{ $text }) {
      my $li = $self->dom->create_element('li');
      $list->append_child($li);
      if (defined $text_is_html && $text_is_html == 0) {
        $li->inner_text($_);
      }
      else {
        $li->inner_HTML($_);
      }
    }
    $notes->append_child($list);
  }
  else {
    my $div = $self->dom->create_element('div');
    if (defined $text_is_html && $text_is_html == 0) {
      $div->inner_text($text);
    }
    else {
      $div->inner_HTML($text);
    }
    $notes->append_child($div);
  }
  $self->{'__'.$location.'_notes'} = $notes;
  return $notes;
}

1;