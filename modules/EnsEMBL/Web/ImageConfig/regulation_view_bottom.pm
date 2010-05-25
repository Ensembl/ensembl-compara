package EnsEMBL::Web::ImageConfig::regulation_view_bottom;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title         => 'Feature context bottom',
    show_buttons  => 'no',
    show_labels   => 'yes',
    label_width   => 113,
    opt_lines     => 1,
    margin        => 5,
    spacing       => 2,
  });  

  $self->create_menus(
    transcript     => 'Genes',
    other          => 'Decorations',
    information    => 'Information',
  );

  $self->add_tracks('other',
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', tag => 0, strand => 'r', menu => 'no',}],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'r', name => 'Scale bar', menu => 'no' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'r', name => 'Ruler', menu => 'no' }],
    [ 'fg_regulatory_features_legend', 'Reg. Features Legend', 'fg_regulatory_features_legend', { display => 'normal', strand => 'r', menu => 'no', colourset => 'fg_regulatory_features' }],
  );
  
  $self->load_tracks;

}
1;
