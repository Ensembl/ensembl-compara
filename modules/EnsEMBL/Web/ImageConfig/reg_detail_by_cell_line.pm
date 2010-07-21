package EnsEMBL::Web::ImageConfig::reg_detail_by_cell_line;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title             => 'Cell line evidence',
    show_buttons      => 'no',
    show_labels       => 'yes',
    label_width       => 113,
    opt_lines         => 1,
    margin            => 5,
    spacing           => 2,
  });  

  $self->create_menus(
    functional     => 'Functional Genomics',
    other          => 'Decorations',
  );
=cut
  $self->add_tracks('other',
    [ 'fg_multi_wiggle',          '', 'fg_multi_wiggle',          { display => 'tiling', strand => 'r', menu => 'no', colourset => 'feature_set', height => 120 }],
);
=cut
  $self->load_tracks;

}
1;
