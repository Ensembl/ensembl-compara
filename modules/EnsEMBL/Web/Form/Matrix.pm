=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Form::Matrix;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Table);

use constant {
  CSS_CLASS                   => 'matrix ss',
  CSS_CLASS_HEADING           => 'fm-heading',
  CSS_CLASS_ODD_ROW           => 'bg1',
  CSS_CLASS_EVEN_ROW          => 'bg2',
  CSS_CLASS_CELLS             => 'ff-mcell',
  CSS_CLASS_SELECTALL_ROW     => 'select_all_row',    #JS purposes
  CSS_CLASS_SELECTALL_COLUMN  => 'select_all_column', #JS purposes
  SUB_HEADING_TAG             => 'p',
  CSS_CLASS_SUB_HEADING       => 'matrixhead',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->{'__columns'}          = [];
  $self->{'__rows_name'}        = {};
  $self->{'__name_prefix'}      = '';
  $self->{'__selectall_label'}  = '';
  $self->{'__selectall'}        = 1;
  $self->{'__row_keys'}         = [];
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
    my @values = ('custom', 'default', 'all', @{$self->{'__row_keys'}}, 'none');
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
  
  #set columns' width
  $_->set_attribute('style', 'width:'.substr(($_->get_attribute('colspan') || 1) * 100/(2 + scalar @{$self->{'__columns'}}), 0, 5).'%') for @{$self->get_elements_by_tag_name(['th', 'td'])};

  return $self->SUPER::render;
}

sub configure {
  ## Configures the matrix with some extra info
  ## @params HashRef with following keys
  ##  - name_prefix     prefix that goes to all checkboxes' name attribute
  ##  - selectall       flag if off, does not add selectall checkboxes
  ##  - selectall_label Label for the cell that is an intersection of row and column containint selectall checkboxes
  my ($self, $params) = @_;
  my @keys = qw(name_prefix selectall selectall_label);
  exists $params->{$_} and $self->{'__'.$_} = $params->{$_} for @keys;
}

sub add_columns {
  ## Adds columns to the matrix
  ## Works only before adding rows
  ## @params ArrayRef of HashRef with keys
  ##    - caption         Column heading
  ##    - name            prefix for name attrib of all the checkbox in this column
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
  my $td    = $self->dom->create_element('td', {'colspan' => scalar @{$self->{'__columns'}} + 2});
  my $h     = $self->dom->create_element($self->SUB_HEADING_TAG, {'class' => $self->CSS_CLASS_SUB_HEADING});
  $h->inner_text($heading) if defined $heading;
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
  ## @return DOM::Node::Element::Tr object
  my ($self, $name, $row, $caption) = @_;
  
  $caption = ucfirst $name unless defined $caption;
  
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
  my $td = $self->dom->create_element('td', {'inner_HTML' => "<b>$caption</b>"});
  $tr->append_child($td);

  #selectall checkbox
  if ($self->{'__selectall'}) {
    my $td = $self->dom->create_element('td');
    my $selectall = $self->dom->create_element('inputcheckbox', {
      'class' =>  $self->CSS_CLASS_SELECTALL_ROW,
      'id'    =>  $self->{'__name_prefix'}.$name.'_r',
      'name'  =>  $self->{'__name_prefix'}.$name,
      'value' =>  'select_all',
    });
    my $label = $self->dom->create_element('label', {
      'inner_HTML'  => 'Select all',
      'for'         => $selectall->id,
    });
    $td->append_child($selectall);
    $td->append_child($label);
    $tr->append_child($td);
  }
  else {
    $td->set_attribute('colspan', 2);
  }
  
  #other row checkboxes
  foreach my $column (@{$self->{'__columns'}}) {
    my $td = $self->dom->create_element('td', {'class' => $self->CSS_CLASS_CELLS});
    my $checkbox = $self->dom->create_element('inputcheckbox', {'name' => $self->{'__name_prefix'}.$column->{'name'}.':'.$name, 'value' => 'on'});
    
    if ($row->{$column->{'name'}}->{'enabled'}) {
      $checkbox->set_attribute('class' => "$self->{'__name_prefix'}$column->{'name'} $self->{'__name_prefix'}$name " . $self->_row_key);
    } else {
      $checkbox->disabled(1);
    }
    
    $checkbox->checked(1) if $row->{$column->{'name'}}->{'checked'};
    $checkbox->set_attribute('class', 'default') if $row->{$column->{'name'}}->{'default'};
    $checkbox->set_attribute('class', $row->{$column->{'name'}}->{'class'}) if $row->{$column->{'name'}}->{'class'};
    $checkbox->set_attribute('title', $row->{$column->{'name'}}->{'title'}) if $row->{$column->{'name'}}->{'title'};

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
  $tr1->append_child($self->dom->create_element('th', {'colspan' => 2}));
  $tr2->append_child($self->dom->create_element('td'));
  $tr2->append_child($self->dom->create_element('td', {'inner_HTML' => $self->{'__selectall_label'}}));
  
  #add columns
  foreach my $column (@{$self->{'__columns'}}) {

    #column heading
    $tr1->append_child($self->dom->create_element('th', {'inner_HTML', $column->{'caption'}, 'class' => $self->CSS_CLASS_CELLS}));

    #selectall checkbox
    my $td = $self->dom->create_element('td', {'class' => $self->CSS_CLASS_CELLS});
    if ($self->{'__selectall'}) {
      my $selectall = $self->dom->create_element('inputcheckbox', {
        'class' => $self->CSS_CLASS_SELECTALL_COLUMN,
        'id'    => $self->{'__name_prefix'}.$column->{'name'}.'_c',
        'name'  => $self->{'__name_prefix'}.$column->{'name'},
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
