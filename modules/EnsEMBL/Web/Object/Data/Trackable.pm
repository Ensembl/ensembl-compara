package EnsEMBL::Web::Object::Data::Trackable;

## Parent class for data objects that can be tracked by user and timestamp
## Can be multiply-inherited with Object::Data::Owned

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_queriable_field({ name => 'created_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_by', type => 'int' });
  $self->add_queriable_field({ name => 'created_by', type => 'int' });

}

}

1;
