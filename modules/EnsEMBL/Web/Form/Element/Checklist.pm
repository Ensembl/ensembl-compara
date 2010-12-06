package EnsEMBL::Web::Form::Element::Checklist;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

use constant {
  CSS_CLASS_SUBHEADING    => 'optgroup',
  CSS_CLASS_WRAPPER       => 'ff-checklist',
  SELECT_DESELECT_CAPTION => '<u><b>Select/deselect all</b></u>',
};

sub __multiple {
  ## Override in child class if required
  return 1;
}

sub __input {
  ## Override in child class if required
  return 'inputcheckbox';
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->set_attribute('id',    $params->{'id'})    if exists $params->{'id'};
  $self->set_attribute('class', $params->{'class'}) if exists $params->{'class'};
  
  $self->{'__name'}     = $params->{'name'} || '';
  $self->{'__disabled'} = exists $params->{'disabled'} && $params->{'disabled'} == 1 ? 1 : 0;
  $self->{'__inline'}   = exists $params->{'inline'} && $params->{'inline'} == 1 ? 1 : 0;

  my $checked_values = {};
  if (exists $params->{'value'}) {
    $params->{'value'}  = [ $params->{'value'} ] unless ref($params->{'value'}) eq 'ARRAY';
    $params->{'value'}  = [ shift @{$params->{'value'}} ] unless $self->__multiple;
    $checked_values     = { map { $_ => 1 } @{$params->{'value'}} };
  }
  if (exists $params->{'selectall'}) {
      $self->add_option({
        'value'         => 'select_all',
        'caption'       => $self->SELECT_DESELECT_CAPTION,
        'checked'       => exists $_->{'value'} && exists $checked_values->{$_->{'value'}} ? 1 : 0,
        'group'         => $_->{'group'}  || ''
      });
  }
  if (exists $params->{'values'}) {
    for (@{$params->{'values'}}) {
      my $args = {};
      $args->{'value'}          =  $_->{'value'} if exists $_->{'value'};
      $args->{'caption'}        =  $_->{'caption'} if exists $_->{'caption'};
      $args->{'checked'}        =  exists $_->{'value'} && defined $_->{'value'} && exists $checked_values->{$_->{'value'}} ? 1 : 0;
      $args->{'group'}          =  $_->{'group'} if exists $_->{'group'};
      $args->{'name'}           =  $_->{'name'} if exists $_->{'name'};
      $args->{'is_plain_text'}  =  $_->{'is_plain_text'} if $_->{'is_plain_text'};
      $self->add_option($args);
    }
  }
}

sub add_option {
  ## Adds an option to the dropdown
  ## @params HashRef with following keys:
  ##  - id            Id attribute of <input>
  ##  - value         goes in value attribute of the option
  ##  - caption       goes as innerText in <option> (is the actual name displayed)
  ##  - selected      flag to tell whether option is selected or not
  ##  - group         (optional) Subheading caption - If subheading does not exist, a new one's created before adding it
  ##  - name          (optional) Only needed to overwrite the default name attribute (one for the whole checklist)
  ##  - is_plain_text Flag to be on if caption is NOT HTML
  ## @return newly added Node::Element::P/Span object containg an input and a label
  my ($self, $params) = @_;
  
  $params->{'value'}    = '' unless exists $params->{'value'} && defined $params->{'value'};
  $params->{'caption'}  = '' unless exists $params->{'caption'} && defined $params->{'caption'};
  my $is_plain_text     = $params->{'is_plain_text'} ? 1 : 0;
  
  my $wrapper = $self->dom->create_element($self->{'__inline'} == 1 ? 'span' : 'p');
  my $input   = $self->dom->create_element($self->__input);
  my $label   = $self->dom->create_element('label');
  
  $wrapper->append_child($input);
  $wrapper->set_attribute('class', $self->CSS_CLASS_WRAPPER);
  $input->set_attribute('id', $params->{'id'} || $self->unique_id);
  $input->set_attribute('value', $params->{'value'});
  $input->set_attribute('name', $params->{'name'} || $self->{'__name'});
  $input->disabled($self->{'__disabled'});
  $input->checked(1) if exists $params->{'checked'} && $params->{'checked'} == 1;
  if ($params->{'caption'} ne '') {
    $wrapper->append_child($label);
    $input->set_attribute('id', $self->unique_id) unless $input->id;
    $label->set_attribute('for', $input->id);
    if ($is_plain_text) {
      $label->inner_text($params->{'caption'});
    }
    else {
      $label->inner_HTML($params->{'caption'});
    }
  }
  
  my $next_heading = undef;
  if (exists $params->{'group'} && defined $params->{'group'}) {
  
    my $match = 0;
    for (@{$self->get_elements_by_class_name($self->CSS_CLASS_SUBHEADING)}) {
      if ($match) {
        $next_heading = $_;
        last;
      }
      $match = 1 if $_->inner_HTML eq $params->{'group'};
    }
    unless ($match) {
      my $heading = $self->dom->create_element('p');
      $heading->inner_HTML($params->{'group'});
      $heading->set_attribute('class', $self->CSS_CLASS_SUBHEADING);
      $self->append_child($heading);
    }
  }
  if (defined $next_heading) {
    $self->insert_before($wrapper, $next_heading);
  }
  else {
    $self->append_child($wrapper);
  }
  return $wrapper;
}

1;