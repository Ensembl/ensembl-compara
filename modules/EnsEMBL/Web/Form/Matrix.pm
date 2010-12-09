package EnsEMBL::Web::Form::Matrix;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Table);

use constant {
  CSS_CLASS                   => 'matrix',
  CSS_CLASS_HEADING           => 'fm-heading',
  CSS_CLASS_ODD_ROW           => 'bg1',
  CSS_CLASS_EVEN_ROW          => 'bg2',
  CSS_CLASS_SELECTALL_ROW     => 'select_all_row',    #JS purposes
  CSS_CLASS_SELECTALL_COLUMN  => 'select_all_column', #JS purposes
  SUB_HEADING_TAG             => 'p',
  CSS_CLASS_SUB_HEADING       => 'matrixhead',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->{'__columns'}    = [];
  $self->{'__rows_name'}  = {};
  $self->{'__prefix'}     = '';
  $self->{'__row_keys'}   = [];
  $self->set_attributes({
    'cellspacing' => '0',
    'cellpadding' => '0',
    'class'       => $self->CSS_CLASS
  });
  return $self;
}

sub render {
  ## @overrides
  ## Adds alternative bgColor and select all dropdown before rendering
  my $self = shift;
  if (scalar @{$self->{'__row_keys'}}) {
    my $select_all_columns = $self->get_elements_by_class_name($self->CSS_CLASS_SELECTALL_COLUMN);
    my $dropdown = $self->dom->create_element('select', {'class', $self->CSS_CLASS_SELECTALL_COLUMN});
    my @values = ("", "all", @{$self->{'__row_keys'}}, "none");
    $dropdown->append_child($self->dom->create_element('option', {'inner_HTML' => ucfirst $_, 'value' => $_})) for @values;
    for (@$select_all_columns) {
      my $dd = $dropdown->clone_node(1);
      $dd->set_attributes({'id' => $_->id, 'name', $_->name});
      my $labels = $_->parent_node->get_elements_by_tag_name('label');
      $labels->[0]->remove if scalar @$labels;
      $_->parent_node->replace_child($dd, $_);
    }
  }
  
  my $i = 0;
  for (@{$self->get_elements_by_tag_name('tr')}) {
    $_->set_attribute('class', $i % 2 == 0 ? $self->CSS_CLASS_EVEN_ROW : $self->CSS_CLASS_ODD_ROW) unless $i == 0;
    $i++;
  }
  return $self->SUPER::render;
}

sub set_input_prefix {
  ## Sets a prefix for all the checkboxes that are appended inside this Matrix box
  ## @params prefix string
  my ($self, $prefix) = @_;
  $self->{'__prefix'} = $prefix || '';
}

sub add_columns {
  ## Adds columns to the matrix
  ## Works only before adding rows
  ## @params ArrayRef of HashRef with keys
  ##    - caption     Column heading
  ##    - name        prefix for name attrib of all the checkbox in this column
  ##    - selectall   flag telling whether or not to display selectall checkbox on the top - ON by default
  my ($self, $columns) = @_;
  if ($self->has_child_nodes) {
    warn 'Columns can be added only before adding any row or subheading.';
    return;
  }
  my $existing_column_names = { map {$_->{'name'} => 1} @{$self->{'__columns'}} };
  
  #read all requested columns
  for (@{$columns}) {
    
    #name is mandatory
    unless ($_->{'name'}) {
      warn 'Name can not be blank';
      return;
    }
    
    #name can not be duplicate
    if (exists $existing_column_names->{$_->{'name'}}) {
      warn 'Column with name '.$_->{'name'}.' already exists';
      return;
    }
    push @{$self->{'__columns'}}, {
      'name'      => $_->{'name'},
      'caption'   => $_->{'caption'} || '',
      'selectall' => exists $_->{'selectall'} && $_->{'selectall'} == 0 ? 0 : 1, #1 by default
    };
  }
}

sub add_column {
  ## Replacement of add_columns if only one column is being added
  ## @params HashRef instead ArrayRef of all column HashRefs
  return shift->add_columns([ shift ]);
}

sub add_subheading {
  ## Adds a subheading to the matrix table
  ## @params Heading html
  ## @params Identification Key that goes inside the class of every row element added after this heading. For use of JS.
  ## @return DOM::Node::Element::Tr object
  my ($self, $heading, $key) = @_;
  
  #add columns HTML if not already there - or refuse to add subheading if no columns were added
  unless ($self->has_child_nodes || $self->_add_columns) {
    warn 'No column added yet. Add columns before adding a subheading';
    return;
  }
  
  $self->_row_key($key || '');

  my $tbody = $self->get_elements_by_tag_name('tbody')->[0];
  my $tr    = $self->dom->create_element('tr');
  my $td    = $self->dom->create_element('td');
  my $h     = $self->dom->create_element($self->SUB_HEADING_TAG);
  $h->inner_text($heading) if defined $heading;
  $h->set_attribute('class', $self->CSS_CLASS_SUB_HEADING);
  $td->set_attribute('colspan', scalar @{$self->{'__columns'}} + 2);
  $td->append_child($h);
  $tr->append_child($td);
  return $tbody->append_child($tr);
}

sub add_row {
  ## Adds a row to the matrix
  ## @params Name suffix for each checkboxes in the row
  ## @params HashRef with keys same as the column names
  ##    - if checkbox needs to be checked & enabled for a column, column_name => 'ce' or 'ec'
  ##    - if checkbox does not need to be checked, but enabled for a column, column_name => 'e'
  ##    - if checkbox needs to be disabled, but checked for a column, column_name => 'c'
  ##    - if neither checked nor enabled, column_name => ''
  ## @params Caption string
  ## @params Flag to state whether or not display selectall checkbox
  ## @return DOM::Node::Element::Tr object
  my ($self, $name, $row, $caption, $selectall) = @_;
  
  $caption = ucfirst $name unless defined $caption;
  $selectall = defined $selectall && $selectall == 0 ? 0 : 1;
  
  #VALIDATION 1 - add columns HTML if not already there - or refuse to add rows if no columns were added
  unless ($self->has_child_nodes || $self->_add_columns) {
    warn 'No column added yet. Add columns before adding a row';
    return;
  }
  
  #VALIDATION 2 - name is mandatory
  unless ($name) {
    warn 'Name can not be blank';
    return;
  }

  #VALIDATION 3 - name can not be duplicate
  if (exists $self->{'__rows_name'}{$name}) {
    warn "Row with name $name already exists";
    return;
  }

  my $tbody = $self->get_elements_by_tag_name('tbody')->[0];
  
  #now add row <tr> to <tbody>
  my $tr = $self->dom->create_element('tr');
  my $td = $self->dom->create_element('td');
  $td->inner_HTML("<b>$caption</b>");
  $tr->append_child($td);

  #selectall checkbox
  if ($selectall) {
    my $td = $self->dom->create_element('td');
    my $selectall = $self->dom->create_element('inputcheckbox');
    my $label     = $self->dom->create_element('label');
    $selectall->set_attribute('class',  $self->CSS_CLASS_SELECTALL_ROW);
    $selectall->set_attribute('id',     $self->{'__prefix'}.$name.'_r');
    $selectall->set_attribute('name',   $self->{'__prefix'}.$name);
    $selectall->set_attribute('value',  'select_all');
    $label->inner_HTML('Select all');
    $label->set_attribute('for', $selectall->id);
    $td->append_child($selectall);
    $td->append_child($label);
    $tr->append_child($td);
  }
  else {
    $td->set_attribute('colspan', 2);
  }
  
  #other row checkboxes
  foreach my $column (@{$self->{'__columns'}}) {
    $row->{$column->{'name'}} ||= '';
    my $td = $self->dom->create_element('td');
    my $checkbox = $self->dom->create_element('inputcheckbox');
    $checkbox->set_attribute('name', $self->{'__prefix'}.$column->{'name'}.':'.$name);
    $checkbox->set_attribute('value', 'on');
    if ($row->{$column->{'name'}} =~ /e/) {
      $checkbox->set_attribute('class', $self->{'__prefix'}.$column->{'name'}); #For JS
      $checkbox->set_attribute('class', $self->{'__prefix'}.$name);             #For JS
      $checkbox->set_attribute('class', $self->_row_key);                       #For JS
    }
    else {
      $checkbox->disabled(1);
    }
    $checkbox->checked(1) if $row->{$column->{'name'}} =~ /c/;

    $td->append_child($checkbox);
    $tr->append_child($td);
  }
  return $tbody->append_child($tr);
}

sub _add_columns {
  my $self  = shift;
  
  return 0 unless scalar @{$self->{'__columns'}};
  
  my $thead = $self->dom->create_element('thead');
  my $tbody = $self->dom->create_element('tbody');
  my $tr1   = $self->dom->create_element('tr');
  my $tr2   = $self->dom->create_element('tr');
  
  #add two empty columns for row caption and selectall button of every row
  $tr1->append_child($self->dom->create_element('th', {'colspan', '2'}));
  $tr2->append_child($self->dom->create_element('td', {'colspan', '2'}));
  
  #add columns
  foreach my $column (@{$self->{'__columns'}}) {

    #column heading
    $tr1->append_child($self->dom->create_element('th', {'inner_HTML', $column->{'caption'}}));

    #selectall checkbox
    my $td = $self->dom->create_element('td');
    if ($column->{'selectall'}) {
      my $selectall = $self->dom->create_element('inputcheckbox', {
        'class' => $self->CSS_CLASS_SELECTALL_COLUMN,
        'id'    => $self->{'__prefix'}.$column->{'name'}.'_c',
        'name'  => $self->{'__prefix'}.$column->{'name'},
        'value' => 'select_all'
      });
      my $label = $self->dom->create_element('label', {'for', $selectall->id});
      $label->inner_HTML('Select all');
      $td->append_child($selectall);
      $td->append_child($label);
    }
    $tr2->append_child($td);
  }
  $thead->append_child($tr1);
  $tbody->append_child($tr2) if scalar @{$tr2->get_elements_by_tag_name('input')}; #add only if selectall boxes added
  $self->append_child($thead);
  $self->append_child($tbody);
  return 1;
}

sub _row_key {
  my $self = shift;
  push @{$self->{'__row_keys'}}, shift if @_;
  return scalar @{$self->{'__row_keys'}} ? $self->{'__row_keys'}->[-1] : '';
}

1;