package EnsEMBL::Web::Data::Trackable;

## Parent class for data objects that can be tracked by user and timestamp
## Can be multiply-inherited with Object::Data::Owned

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data;

our @ISA = qw(EnsEMBL::Web::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_trackable(1);
  $self->add_queriable_field({ name => 'created_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_by', type => 'int' });
  $self->add_queriable_field({ name => 'created_by', type => 'int' });

}

}

1;
