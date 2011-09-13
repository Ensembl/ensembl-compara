package EnsEMBL::Web::Component::Gene::SVTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;  
  my $slice   = $object->slice;
  my $html    = $self->structrual_variation_table($slice, 'Structural variants',         'sv',  'get_all_StructuralVariationFeatures', 1);
     $html   .= $self->structrual_variation_table($slice, 'Copy number variants probes', 'cnv', 'get_all_CopyNumberVariantProbeFeatures');
  
  return $html;
}

1;
