#$Id$
package EnsEMBL::Web::Object::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Object::Feature);

sub short_caption {
  my $self = shift;
  return shift eq 'global' ? 'Phenotype: '.$self->hub->param('name') : 'Phenotype-based displays';
}

sub caption {
  my $self = shift;
  return 'Phenotype '.$self->hub->param('name');
}


1;
