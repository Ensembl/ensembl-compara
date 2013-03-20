# $Id$

package EnsEMBL::Web::ImageConfig::StructuralVariant;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    opt_halfheight   => 1,  # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines        => 1,  # draw registry lines
    sortable_tracks  => 'drag', # allow the user to reorder tracks on the image
    show_labels      => 'yes',  # show track names on left-hand side
  });
  
  $self->create_menus(qw(
    sequence
    transcript
    prediction
    variation
    somatic
    functional
    information
    other
  ));
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );

   $self->add_tracks('information',
    [ 'variation_legend', '', 'variation_legend', { display => 'normal', strand => 'r', name => 'Variation Legend', caption => 'Variation legend' }]
  );
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  $self->load_tracks;
  
  # structural variations
  $self->modify_configs(
    [ 'variation_feature_structural' ],
    { display => 'normal', depth => 100 }
  );
  
  # Somatic structural variations
  $self->modify_configs(
    [ 'somatic_sv_feature' ],
    { display => 'normal', depth => 50 }
  );
   
  # genes
  $self->modify_configs(
    ['transcript_core_ensembl'],
    { display => 'transcript_label' }
  );
}

1;
