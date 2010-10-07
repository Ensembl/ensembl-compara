# $Id$

package EnsEMBL::Web::Component::Interface::List;

### Module to create generic record list for Interface and its associated modules

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Interface);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  my $self = shift;
  return $self->object->interface->caption('list') || 'All Records';
}

sub content {
### Displays a record or form input as non-editable text,
### and also passes the data as hidden form elements
  my $self      = shift;
  my $object    = $self->object;
  my $interface = $object->interface;
  my @records   = $interface->record_list(undef, $self->hub->user);
  my $columns   = $interface->option_columns || $interface->element_order;

  my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '0px' });
  my $width = int(100/scalar(@$columns));
  
  foreach my $column (@$columns) {
    $table->add_columns({ key => $column, title => ucfirst $column, width => $width, align => 'left' });
  }
  
  foreach my $record (@records) {
    my $row = {};
    
    foreach my $column (@$columns) {
      $row->{$column} = $record->$column || '&nbsp;';
    }
    
    $table->add_row($row);
  }
  
  return $table->render;
}

1;
