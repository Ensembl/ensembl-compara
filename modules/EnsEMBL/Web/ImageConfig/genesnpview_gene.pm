package EnsEMBL::Web::ImageConfig::genesnpview_gene;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title            => 'Genes',
    show_buttons     => 'no',  # show +/- buttons
    button_width     => 8,     # width of red "+/-" buttons
    show_labels      => 'yes', # show track names on left-hand side
    label_width      => 100,   # width of labels on left-hand side
    margin           => 5,     # margin
    spacing          => 2,     # spacing
    opt_halfheight   => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,     # include empty tracks
  });
  
  $self->create_menus(      
    transcript => 'Other Genes',
    variation  => 'Variations',
    somatic          => 'Somatic Mutations',
    other      => 'Other'
  );
  
  $self->load_tracks;

  $self->add_tracks('variation',
    [ 'snp_join',         '', 'snp_join',         { display => 'on',     strand => 'b', menu => 'no', tag => 0, colours => $self->species_defs->colour('variation') }],
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque', src => 'all' }]
  );
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'f', menu => 'no' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', menu => 'no', notext => 1 }],
    [ 'spacer',   '', 'spacer',   { display => 'normal', strand => 'r', menu => 'no', height => 50 }]
  );
  
  $self->modify_configs(
    [ 'transcript' ],
    { display => 'off' }
  );
  
  $self->modify_configs(
    [ 'variation' ],
    { menu => 'no' }
  );
  
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', caption => 'Variations', strand => 'f' }
  );
}

1;
