# $Id$

package EnsEMBL::Web::ImageConfig::genespliceview_gene;

use strict;

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
    other      => ''
  );
  
  $self->load_tracks;
  
  $self->add_tracks('other',
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
}

1;
