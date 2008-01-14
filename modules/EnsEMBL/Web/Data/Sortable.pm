package EnsEMBL::Web::Data::Sortable;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Data::Trackable  EnsEMBL::Web::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('sortable');
  $self->attach_owner('user');
  $self->add_field({ name => 'kind', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
