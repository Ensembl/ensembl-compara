package EnsEMBL::Web::ImageConfig::tsv_transcript;

use warnings;
no warnings 'uninitialized';
use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title            => 'Transcript slice',
    _options         => [qw(pos col known unknown)],
    show_buttons     => 'no',  # show +/- buttons 
    button_width     => 8,     # width of red "+/-" buttons
    show_labels      => 'yes', # show track names on left-hand side
    label_width      => 100,   # width of labels on left-hand side
    margin           => 5,     # margin
    spacing          => 2,     # spacing
    opt_halfheight   => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,     # include empty tracks..
    _add_labels      => 1, 
  });

  $self->create_menus(
    transcript => 'Genes',
    variation  => 'Variations',
    somatic    => 'Somatic Mutations',
    prediction => 'Prediction transcripts',
    other      => 'Decorations'
  );
 
  $self->load_tracks;

  $self->modify_configs(
    [ 'transcript' ],
    { display => 'off' }
  );
  $self->add_tracks('transcript',
    [ 'snp_join', '', 'snp_join', { display => 'on', strand => 'b', tag => 0, colours => $self->species_defs->colour('variation'), menu => 'no' }]
  );
  
  $self->add_tracks('other',
    [ 'transcriptexon_bgtrack', '', 'transcriptexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no' , src => 'all', colours => 'bisque', tag => 0 }],
    [ 'scalebar',               '', 'scalebar',               { display => 'normal', strand => 'f', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',                  '', 'ruler',                  { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed', notext => 1 }],
    [ 'spacer',                 '', 'spacer',                 { display => 'normal', strand => 'r', menu => 'no', height => 20 }]
  );
  
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', caption => 'Variations', strand => 'f' }
  );
}

1;
