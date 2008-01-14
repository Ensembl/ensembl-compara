package EnsEMBL::Web::Data::CurrentConfig;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Data::Trackable  EnsEMBL::Web::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('currentconfig');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'config', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
