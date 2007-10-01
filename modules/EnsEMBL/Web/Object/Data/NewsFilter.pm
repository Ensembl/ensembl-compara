package EnsEMBL::Web::Object::Data::NewsFilter;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Record;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Record);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('news');
  $self->attach_owner($args->{'record_type'});
  #$self->add_field({ name => 'topic', type => 'text' });
  $self->add_field({ name => 'species', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
