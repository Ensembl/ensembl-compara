#$Id$
package EnsEMBL::Web::Object::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Object::Feature);

sub short_caption {
  my $self = shift;
  my $name = $self->get_phenotype_desc;
  return shift eq 'global' ? "Phenotype: $name" : 'Phenotype-based displays';
}

sub caption {
  my $self = shift;
  return $self->get_phenotype_desc;
}

sub get_phenotype_desc {
  my $self = shift;
  my $vardb   = $self->hub->database('variation');
  my $vaa     = $vardb->get_adaptor('VariationAnnotation');
  return $vaa->fetch_phenotype_description_by_id($self->hub->param('ph'));
};

1;
