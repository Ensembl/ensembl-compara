# $Id$

package EnsEMBL::Web::ViewConfig::Matrix::CellLine;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Matrix);

sub matrix_config {
  my $self          = shift;
  my $set           = $self->set;
  my $evidence_info = $self->hub->get_adaptor('get_FeatureTypeAdaptor', 'funcgen')->get_regulatory_evidence_info->{$set};
  
  return {
    menu        => $self->menu,
    section     => 'Regulation',
    caption     => $evidence_info->{'name'},
    header      => $evidence_info->{'long_name'},
    description => $self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'feature_set'}{'analyses'}{'Regulatory_Build'}{'desc'}{$set},
    axes        => { x => 'Cell type', y => 'Evidence type' },
  };
}

1;
