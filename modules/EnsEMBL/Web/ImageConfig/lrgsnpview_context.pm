package EnsEMBL::Web::ImageConfig::lrgsnpview_context;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift; 

  $self->set_parameters({
    title            => 'Context slice',
    show_buttons     => 'no',  # show +/- buttons
    button_width     => 8,     # width of red "+/-" buttons
    show_labels      => 'yes', # show track names on left-hand side
    label_width      => 100,   # width of labels on left-hand side
    margin           => 5,     # margin
    spacing          => 2,     # spacing
    features         => [],
    opt_halfheight   => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,     # include empty tracks..
  });
  
  $self->create_menus(
    sequence   => 'Sequence',
    transcript => 'Genes',
    variation  => 'Germline variation', 
    somatic    => 'Somatic Mutations',
    other      => 'Other'
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks;

  $self->add_tracks('other',
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque', src => 'all' }],
    [ 'draggable',        '', 'draggable',        { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'snp_join',         '', 'snp_join',         { display => 'on',     strand => 'r', menu => 'no', tag => 0, colours => $self->species_defs->colour('variation') }],
    [ 'spacer',           '', 'spacer',           { display => 'normal', strand => 'r', menu => 'no' }],
    [ 'ruler',            '', 'ruler',            { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed' } }],
    [ 'scalebar',         '', 'scalebar',         { display => 'normal', strand => 'f', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }]
  );
  
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', caption => 'Variations' }
  );


}
1;
