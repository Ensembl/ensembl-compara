package EnsEMBL::Web::ImageConfig::snpview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title             => 'Variation Context',
    show_buttons      => 'no',  # do not show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_halfheight    => 1,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,     # draw registry lines
  });
  
  $self->create_menus(
    transcript  => 'Genes',
    prediction  => 'Prediction transcripts',
    sequence    => 'Sequence',
    variation   => 'Variation',
    information => 'Information', 
    other       => 'Decorations'
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->add_tracks('information',
    [ 'variation_legend', '', 'variation_legend', { display => 'normal', strand => 'r', name => 'Variation Legend', caption => 'Variation legend' }]
  );
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );

  $self->load_tracks;

  $self->modify_configs(
    [ 'variation' ],
    { style => 'box', depth => 100000 }
  );
 
  $self->modify_configs(
   [ 'gene_legend' ],
   { display => 'off', menu => 'no' }
  );

  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal' }
  );
  $self->modify_configs(
    ['variation_feature_structural'],
    { display => 'normal' }
  );
}

1;
