package EnsEMBL::Web::Data::Record;

### This class stands for universal record (either User's or Group's)

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Data::Trackable  EnsEMBL::Web::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type( $args->{type} )
    if $args->{type};
  $self->attach_owner($args->{owner})
    if $args->{owner};
  $self->populate_with_arguments($args);
}

}

1;
