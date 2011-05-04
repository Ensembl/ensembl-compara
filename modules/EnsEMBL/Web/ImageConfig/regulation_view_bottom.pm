# $Id$

package EnsEMBL::Web::ImageConfig::regulation_view_bottom;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title       => 'Feature context bottom',
    show_labels => 'yes',
    label_width => 113,
    opt_lines   => 1,
  });  

  $self->create_menus(
    transcript  => 'Genes',
    other       => 'Decorations',
    information => 'Information',
  );

  $self->add_tracks('other',
    [ 'fg_background_regulation',      '',                     'fg_background_regulation',      { display => 'normal', strand => 'r', menu => 'no', tag => 0 }],
    [ 'scalebar',                      '',                     'scalebar',                      { display => 'normal', strand => 'r', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                         '',                     'ruler',                         { display => 'normal', strand => 'r', menu => 'no', name => 'Ruler' }],
    [ 'fg_regulatory_features_legend', 'Reg. Features Legend', 'fg_regulatory_features_legend', { display => 'normal', strand => 'r', menu => 'no', colourset => 'fg_regulatory_features' }],
  );
  
  $self->load_tracks;
}

1;
