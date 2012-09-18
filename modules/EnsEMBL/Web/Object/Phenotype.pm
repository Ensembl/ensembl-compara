#$Id$
package EnsEMBL::Web::Object::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Object::Feature);

sub short_caption {
  my $self = shift;
  my $caption;
  my $name = $self->get_phenotype_desc;
  if (shift eq 'global') {
    $caption = $name ? "Phenotype: $name" : 'Phenotypes';
  }
  else {
    $caption = 'Phenotype-based displays';
  }
  return $caption;
}

sub caption {
  my $self = shift;
  return $self->get_phenotype_desc;
}

sub long_caption {
  my $self = shift;
  $self->has_variants ? 'Locations of variants associated with '.$self->get_phenotype_desc 
                      : 'No variants associated with phenotype '.$self->get_phenotype_desc;
}

sub phenotype_id      { $_[0]->{'data'}{'phenotype_id'} = $_[1] if $_[1]; return $_[0]->{'data'}{'phenotype_id'}; }

sub has_variants {
  my $self = shift;
  return $self->Obj->{'Variation'} ? 1 : 0;
}

sub get_phenotype_desc {
  my $self = shift;
  return unless $self->hub->param('ph');
  my $vardb   = $self->hub->database('variation');
  my $vaa     = $vardb->get_adaptor('VariationAnnotation');
  return $vaa->fetch_phenotype_description_by_id($self->hub->param('ph'));
};

sub get_all_phenotypes {
  my $self = shift;
  my $vardb = $self->hub->database('variation');
  my $pa    = $vardb->get_adaptor('Phenotype');
  return $pa->fetch_all();
};

1;
