# $Id$

package EnsEMBL::Web::ImageConfig::reg_detail_by_cell_line;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title        => 'Cell line tracks',
    show_labels  => 'yes',
    label_width  => 113,
    opt_lines    => 1,
  });  

  $self->create_menus(
    functional => 'Functional Genomics',
    other      => 'Decorations',
  );

  $self->add_tracks('other',
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  $self->load_tracks;

  $self->modify_configs(
    [ 'functional' ],
    { display => 'off', menu => 'no' }
  );

  # Turn off cell line wiggle tracks
  my @cell_lines = sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  
  foreach my $cell_line (@cell_lines) {
    $cell_line =~ s/\:\d*//;
    
    my $display = $cell_line eq 'MultiCell' || $cell_line eq 'CD4' ? 'tiling_feature' : 'compact';

    # Turn on reg_feats track
    $self->modify_configs(
      [ "reg_feats_$cell_line" ],
      { display => 'normal', menu => 'yes'}
    );
    
    # Turn on core evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line" ],
      { display => $display, menu => 'yes'}
    );
    
    # Turn on supporting evidence track
    $self->modify_configs(
      [ "reg_feats_other_$cell_line" ],
      { display => 'compact', menu => 'yes'}
    );
  }
}

1;
