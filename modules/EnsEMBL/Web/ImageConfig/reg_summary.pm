# $Id$

package EnsEMBL::Web::ImageConfig::reg_summary;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks => 1,
    opt_lines       => 1,
  });  

  $self->create_menus(qw(
    sequence
    transcript
    prediction
    dna_align_rna
    simple
    misc_feature
    functional
    variation
    oligo
    repeat
    other
    information
  ));
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks;
  $self->load_configured_das;
  
  $self->modify_configs(
    [ 'regulatory_features', 'functional_other_regulatory_regions' ],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [ 'regulatory_features_core', 'regulatory_features_other' ],
    { display => 'off', menu => 'no' }
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_nolabel' }
  );
}

1;
