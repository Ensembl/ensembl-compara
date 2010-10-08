# $Id$

package EnsEMBL::Web::Component::Interface;

### Module to create generic forms for Document::Interface and its associated modules

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component);

## Some methods common to two or more interface child modules

sub script_name {
  my $self = shift;
  return $self->object->interface->script_name;
}

sub data_form {
  ### Function to build a record editing form
  my ($self, $name, $next) = @_;
  my $hub       = $self->hub;
  my $object    = $self->object;
  my $interface = $object->interface;
  my $url       = '/' . $hub->species;
  $url          = '' if $url !~ /_/;
  $url         .= '/' . $self->script_name . "/$next";
  
  my $form = new EnsEMBL::Web::Form($name, $url, 'post');
  $form->add_attribute('class', 'narrow-labels');

  ## form widgets
  my ($key) = $interface->data->primary_columns;

  my $id = $hub->param($key) || $hub->param('id');
  
  if ($id) {
    #$interface->data->populate($id);
  } else {
    $interface->cgi_populate($object);
  }
  
  $form->add_element(%$_) for @{$interface->edit_fields($object)};
  
  return $form;
}

sub record_select {
  ### Function to build a record selection form
  my ($self, $object, $action) = @_;
  
  my $interface = $object->interface;
  my $script    = $self->script_name($object);
  my $select    = $interface->dropdown ? 'select' : '';
  my $form      = new EnsEMBL::Web::Form('interface_select', "/$script/$action", 'post');
  
  $form->add_attribute('class', 'narrow-labels');
  
  my @options;
  push @options, { name => '--- Choose ---', value => '' } if $select;

  ## Get record index
  my @unsorted_list = $interface->record_list(undef, $self->hub->user);
  my @columns       = @{$interface->option_columns};

  ## Create field type lookup, for sorting purposes
  my %all_fields = %{$interface->data->get_all_field};

  ## Do custom sort
  my ($sort_code, $repeat, @list);
  if ($interface->option_order && ref $interface->option_order eq 'ARRAY') {
    foreach my $sort_col (@{$interface->option_order}) {
      my $col_name = $sort_col->{'column'};
      my $col_order = $sort_col->{'order'} || 'ASC';
      if ($repeat > 0) {
        $sort_code .= ' || ';
      }
      ## build sort function
      my $a = '$a';
      my $b = '$b';
      if ($col_order eq 'DESC') {
        $a = '$b';
        $b = '$a';
      }
      ## try to guess appropriate sort type
      if ($all_fields{$col_name} =~ /^int/ || $all_fields{$col_name} =~ /^float/) {
        $sort_code .= $a.'->'.$col_name.' <=> '.$b.'->'.$col_name.' ';
      }
      else {
        $sort_code .= 'lc '.$a.'->'.$col_name.' cmp lc '.$b.'->'.$col_name.' ';
      }
      $repeat++;
    }
    my $subref = eval "sub { $sort_code }";
    @list = sort $subref @unsorted_list;
  }
  else { 
    @list = @unsorted_list;
  }

  ## Output list
  foreach my $entry (@list) {
    next unless $entry;
    my $value = $entry->id;
    my $text;
    foreach my $col (@columns) {
      $text .= $entry->$col.' - ';
    }
    $text =~ s/ - $//;
    if (length($text) > 50) {
      $text = substr($text, 0, 50).'...';
    }
    push @options, {'name'=>$text, 'value'=>$value};
  }
  
  $form->add_element( 
            'type'    => 'DropDown', 
            'select'  => $select,
            'title'   => 'Select a Record', 
            'name'    => 'id', 
            'values'  => \@options,
  );
  
  return $form;
}


1;
