package EnsEMBL::Web::Form::Layout::Matrix;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Form::Layout);

use constant {
  CSS_CLASS                   => 'form-matrix',
  CSS_CLASS_HEADING           => 'fm-heading',
  CSS_CLASS_EVEN_ROW          => 'fm-even',
  CSS_CLASS_ODD_ROW           => 'fm-odd',
  CSS_CLASS_SELECTALL_ROW     => 'select_all_row',    #JavaScript will read this className to activate 'select all' controls
  CSS_CLASS_SELECTALL_COLUMN  => 'select_all_column', #JavaScript will read this className to activate 'select all' controls
  SUB_HEADING_TAG             => 'h4',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->{'__columns'}    = [];
  $self->{'__rows_name'}  = {};
  $self->{'__prefix'}     = '';
  return $self;
}

sub add_subheading_row {
  ## Adds a subheading to the matrix table
  ## @return DOM::Node::Element::Tr object
  my ($self, $heading) = @_;
  
  #add columns HTML if not already there - or refuse to add subheading if no columns were added
  unless ($self->inner_div->has_child_nodes || $self->_add_columns){
    warn 'No column added yet. Add columns before adding a subheading';
    return;
  }

  my $tbody = $self->get_elements_by_tag_name('tbody')->[0];
  my $tr    = $self->dom->create_element('tr');
  my $td    = $self->dom->create_element('td');
  my $h     = $self->dom->create_element($self->SUB_HEADING_TAG);
  $h->inner_text($heading || '');
  $td->set_attribute('colspan', scalar @{ $self->{'__columns'} } + 2);
  $td->append_child($h);
  $tr->append_child($td);
  $tbody->append_child($tr);
  return $tr;
}

sub set_input_prefix {
  ## Sets a prefix for all the checkboxes that are appended inside this Matrix box
  ## @params prefix string
  my ($self, $prefix) = @_;
  $self->{'__prefix'} = $prefix || '';
}

sub add_column {
  ## Replacement of add_columns if only one column is being added
  ## @params HashRef instead ArrayRef of all column HashRefs
  return shift->add_columns([ shift ]);
}

sub add_columns {
  ## Adds columns to the matrix
  ## Works only before adding rows
  ## @params ArrayRef of HashRef with keys
  ##    - caption     Column heading
  ##    - name        prefix for name attrib of all the checkbox in this column
  ##    - selectall   flag telling whether or not to display selectall checkbox on the top
  my ($self, $columns) = @_;
  if ($self->inner_div->has_child_nodes) {
    warn 'Columns can be added only before adding any row or subheading.';
    return;
  }
  my $column_names = { map {$_->{'name'} => 1} @{ $self->{'__columns'} } };
  
  #read all requested columns
  for (@{ $columns }) {
    
    #name is mandatory
    unless ($_->{'name'}) {
      warn 'Name can not be blank';
      return;
    }
    
    #name can not be duplicate
    if (exists $column_names->{ $_->{'name'} }) {
      warn 'Column with name '.$_->{'name'}.' already exists';
      return;
    }
    push @{ $self->{'__columns'} }, {
      'name'      => $_->{'name'},
      'caption'   => $_->{'caption'} || '',
      'selectall' => exists $_->{'selectall'} && $_->{'selectall'} == 0 ? 0 : 1;
    };
  }
}

sub add_row {
  ## Adds a row to the matrix
  ## @params Name suffix for each checkboxes in the row
  ## @params Ref of a hash with keys same as the column names
  ##    - if checkbox needs to be checked for a column, name => 1
  ##    - if checkbox does not need to be checked for a column, name => 0
  ##    - if checkbox needs to be disabled for a column, skip the name as a key
  ## @params Caption string
  ## @params Flag to state whether or not display selectall checkbox
  ## @return DOM::Node::Element::Tr object
  my ($self, $name, $row, $caption, $selectall) = @_;
  
  $caption ||= ucfirst $name;
  $selectall = defined $selectall && $selectall == 0 ? 0 : 1;
  
  #name is mandatory
  unless ($name) {
    warn 'Name can not be blank';
    return;
  }

  #name can not be duplicate
  if (exists $self->{'__rows_name'}{ $name }) {
    warn "Row with name $name already exists";
    return;
  }
  
  #add columns HTML if not already there - or refuse to add rows if no columns were added
  unless ($self->inner_div->has_child_nodes || $self->_add_columns)
    warn 'No column added yet. Add columns before adding a row';
    return;
  }

  my $tbody = $self->get_elements_by_tag_name('tbody')->[0];
  
  #now add row <tr> to <tbody>
  my $tr = $self->dom->create_element('tr');
  my $td = $self->dom->create_element('td');
  $tr->set_attribute('class', scalar @{ $self->{'__rows_name'} } / 2 == 0 ? $self->CSS_CLASS_EVEN_ROW : $self->CSS_CLASS_ODD_ROW);
  $td->inner_text($caption || '');
  $tr->append_child($td);

  #selectall button
  if ($selectall) {
    my $td = $self->dom->create_element('td');
    my $selectall = $self->dom->create_element('inputcheckbox');
    my $label     = $self->dom->create_element('label');
    $selectall->set_attribute('class', $self->CSS_CLASS_SELECTALL_ROW);
    $selectall->set_attribute('id',    $self->{'__prefix'}.$name.'_r');
    $label->inner_HTML('Select all');
    $label->set_attribute('for', $self->{'__prefix'}.$name.'_r');
    $td->append_child($selectall);
    $td->append_child($label);
    $tr->append_child($td);
  }
  else {
    $td->set_attribute('colspan', 2);
  }
  
  #other row checkboxes
  foreach my $column (@{ $self-{'__columns'} }) {
    my $td = $self->dom->create_element('td');
    my $checkbox = $self->dom->create_element('inputcheckbox');
    $checkbox->set_attribute('name', $self->{'__prefix'}.$column->{'name'}.':'.$name);
    $checkbox->set_attribute('value', 'on');
    $checkbox->disabled(1) unless exists $row->{ $column->{'name'} };
    $checkbox->checked(1) if exists $row->{ $column->{'name'} } && $row->{ $column->{'name'} } == 1;
    $td->append_child($checkbox);
    $tr->append_child($td);
  }
  return $tr;
}

sub _add_columns {
  my $self  = shift;
  my $table = $self->dom->create_element('table');
  my $thead = $self->dom->create_element('thead');
  $tbody    = $self->dom->create_element('tbody');
  my $tr1   = $self->dom->create_element('tr');
  my $tr2   = $self->dom->create_element('tr');
  
  #add two empty columns for row caption and selectall button of every row
  my $th = $self->dom->create_element('th');
  $th->set_attribute('colspan', '2');
  $tr1->append_child($th);
  $tr2->append_child($th->clone_node);
  
  return 0 unless scalar @{ $self->{'__columns'} };

  #add columns
  foreach my $column (@{ $self->{'__columns'} }) {

    #column heading
    my $th = $self->dom->create_element('th');
    $th->inner_text($column->{'caption'});
    $tr1->append_child($th);

    #selectall checkbox
    my $td = $self->dom->create_element('td');
    if ($column->{'selectall'}) {
      my $selectall = $self->dom->create_element('inputcheckbox');
      my $label     = $self->dom->create_element('label');
      $selectall->set_attribute('class', $self->CSS_CLASS_SELECTALL_COLUMN);
      $selectall->set_attribute('id',    $self->{'__prefix'}.$column->{'name'}.'_c');
      $label->inner_HTML('Select all');
      $label->set_attribute('for', $self->{'__prefix'}.$column->{'name'}.'_c');
      $td->append_child($selectall);
      $td->append_child($label);
    }
    $tr2->append_child($td);
  }
  $thead->append_child($tr1);
  $tbody->append_child($tr2) if scalar @{ $tr2->get_elements_by_tag_name('input') }; #add only if selectall boxes added
  $table->append_child($thead);
  $table->append_child($tbody);
  $self->inner_div->append_child($table);
  return 1;
}

1;
