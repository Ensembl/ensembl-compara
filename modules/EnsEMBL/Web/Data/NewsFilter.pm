package EnsEMBL::Web::Data::NewsFilter;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::Data::Record;

our @ISA = qw(EnsEMBL::Web::Data::Trackable  EnsEMBL::Web::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('newsfilter');
  $self->attach_owner($args->{'record_type'});
  #$self->add_field({ name => 'topic', type => 'text' });
  $self->add_field({ name => 'species', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
