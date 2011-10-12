package EnsEMBL::Web::Form::Element::Checklist;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

use constant {
  CSS_CLASS_SUBHEADING    => 'optgroup',
  CSS_CLASS_INNER_WRAPPER => 'ff-checklist',
  SELECT_DESELECT_CAPTION => '<u><b>Select/deselect all</b></u>',
  
  _IS_MULTIPLE           => 1,               ## Overridden in Radiolist
  _ELEMENT_TYPE          => 'inputcheckbox'  ## Overridden in Radiolist
};

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->set_attribute('id',    $params->{'wrapper_id'})    if exists $params->{'wrapper_id'};
  $self->set_attribute('class', $params->{'wrapper_class'}) if exists $params->{'wrapper_class'};

  # default attributes for the checkboxs/radiobuttons
  $self->{'__option_name'}        = $params->{'name'} || '';
  $self->{'__option_disabled'}    = $params->{'disabled'} ? 1 : 0;
  $self->{'__option_class'}       = $params->{'class'} if exists $params->{'class'};
  $self->{'__option_label_first'} = $params->{'label_first'} if exists $params->{'label_first'};
  $self->{'__inline'}             = exists $params->{'inline'} && $params->{'inline'} == 1 ? 1 : 0;

  my $checked_values = {};
  if (exists $params->{'value'}) {
    $params->{'value'}  = [ $params->{'value'} ] unless ref($params->{'value'}) eq 'ARRAY';
    $params->{'value'}  = [ shift @{$params->{'value'}} ] unless $self->_IS_MULTIPLE;
    $checked_values     = { map { $_ => 1 } @{$params->{'value'}} };
  }
  if (exists $params->{'selectall'}) {
    $self->add_option({
      'value'         => 'select_all',
      'caption'       => $self->SELECT_DESELECT_CAPTION
    });
  }
  if (exists $params->{'values'}) {
    for (@{$params->{'values'}}) {
      $_ = {'value' => $_, 'caption' => $_} unless ref $_ eq 'HASH';
      $_->{'checked'} = exists $_->{'value'} && defined $_->{'value'} && exists $checked_values->{$_->{'value'}} ? 1 : 0;
      $self->add_option($_);
    }
  }
}

sub add_option {
  ## Adds an option to the dropdown
  ## @params HashRef with following keys:
  ##  - id          Id attribute of <input>
  ##  - value       goes in value attribute of the option
  ##  - caption     Text string (or hashref set of attributes including inner_HTML or inner_text) for <label>, appearing right side of the checkbox/radiobutton
  ##  - label_first flag if on, will add the label to the left of the checkbox/radiobutton - overrides the 'label_first' flag provided to the element
  ##  - selected    flag to tell whether option is selected or not
  ##  - group       Subheading caption - If subheading does not exist, a new one's created before adding it
  ##  - class       Only needed to override the default class attribute for all options
  ##  - name        Only needed to override the default name attribute for all options
  ##  - disabled    Only needed to override the default enabled status for all options
  ## @return newly added Node::Element::P/Span object containg an input and a label
  my ($self, $params) = @_;
  
  my $dom = $self->dom;

  $params->{'value'}         = '' unless exists $params->{'value'} && defined $params->{'value'};
  $params->{'class'}       ||= $self->{'__option_class'}       if $self->{'__option_class'};
  $params->{'label_first'} ||= $self->{'__option_label_first'} if $self->{'__option_label_first'};
  $params->{'id'}          ||= $self->unique_id                if exists $params->{'caption'}; #'for' attrib for label if caption provided

  my $wrapper = $dom->create_element($self->{'__inline'} ? 'span' : 'p', {'class' => $self->CSS_CLASS_INNER_WRAPPER});
  my $input   = $dom->create_element($self->_ELEMENT_TYPE, {'value' => $params->{'value'}, 'name' => $params->{'name'} || $self->{'__option_name'}});

  $params->{$_} and $input->set_attribute($_, $params->{$_}) for qw(id class);
  $input->disabled(exists $params->{'disabled'} ? ($params->{'disabled'} ? 1 : 0) : $self->{'__option_disabled'});
  $input->checked(1) if exists $params->{'checked'} && $params->{'checked'} == 1;
  
  my @children = ($input, exists $params->{'caption'} ? {'node_name' => 'label', 'for' => $input->id, ref $params->{'caption'} eq 'HASH' ? %{$params->{'caption'}} : 'inner_text' => $params->{'caption'}} : ());
  $wrapper->append_children($params->{'label_first'} ? reverse @children : @children);

  my $next_heading = undef;
  if (exists $params->{'group'} && defined $params->{'group'}) {
    my $match = 0;
    for (@{$self->get_elements_by_class_name($self->CSS_CLASS_SUBHEADING)}) {
      $match and $next_heading = $_ and last;
      $match = 1 if $_->inner_HTML eq $params->{'group'};
    }
    $self->append_child('p', {'inner_HTML' => $params->{'group'}, 'class' => $self->CSS_CLASS_SUBHEADING}) unless $match; #create new heading if no match found
  }
  return defined $next_heading ? $self->insert_before($wrapper, $next_heading) : $self->append_child($wrapper);
}

1;