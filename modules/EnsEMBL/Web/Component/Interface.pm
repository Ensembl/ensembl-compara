package EnsEMBL::Web::Component::Interface;

### Module to create generic forms for Document::Interface and its associated modules

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Form;
use base qw( EnsEMBL::Web::Component);

## Some methods common to two or more interface child modules

sub script_name {
  my $self = shift;
  return $self->object->interface->script_name;
}

sub data_form {
  ### Function to build a record editing form
  my ($self, $name, $next) = @_;
  my $object = $self->object;
  my $url = '/'.$object->species;
  $url = '' if $url !~ /_/;
  $url .= '/'.$self->script_name.'/'.$next;
  my $form = EnsEMBL::Web::Form->new($name, $url, 'post');
  $form->add_attribute('class', 'narrow-labels');

  ## form widgets
  my ($key) = $object->interface->data->primary_columns;
  if ($object->param('owner_type')) {
    #$object->interface->data->attach_owner($object->param('owner_type'));
  }
  my $id = $object->param($key) || $object->param('id');
  if ($id) {
    #$object->interface->data->populate($id);
  } else {
    $object->interface->cgi_populate($object);
  }
  my $widgets = $object->interface->edit_fields($object);

  foreach my $element (@$widgets) {
    $form->add_element(%$element);
  }
  return $form;
}

sub record_select {
  ### Function to build a record selection form
  my($self, $object, $action) = @_;
  
  my $script = $self->script_name($object);
  my $form = EnsEMBL::Web::Form->new('interface_select', "/$script/$action", 'post');
  $form->add_attribute('class', 'narrow-labels');

  my $select  = $object->interface->dropdown ? 'select' : '';
  my @options;
  if ($select) {
    push @options, {'name'=>'--- Choose ---', 'value'=>''};
  }

  ## Get record index
  my @unsorted_list = $object->interface->record_list;
  my @columns = @{$object->interface->option_columns};

  ## Create field type lookup, for sorting purposes
  my %all_fields = %{ $object->interface->data->get_all_fields };

  ## Do custom sort
  my ($sort_code, $repeat, @list);
  if ($object->interface->option_order && ref($object->interface->option_order) eq 'ARRAY') {
    foreach my $sort_col (@{$object->interface->option_order}) {
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
