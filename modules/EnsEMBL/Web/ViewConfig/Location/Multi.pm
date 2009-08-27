package EnsEMBL::Web::ViewConfig::Location::Multi;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
  my $view_config = shift;

  $view_config->_set_defaults(qw(
    panel_top       yes
    panel_zoom      no
    zoom_width      100
    context         1000
    pairwise_blastz no
    pairwise_tblat  no
    pairwise_align  no
  ));
  
  $view_config->add_image_configs({qw(
    MultiIdeogram    nodas
    MultiTop         nodas
    MultiBottom      nodas
  )});
  
  $view_config->storable = 1;
}

sub form {
  my $view_config = shift;
  
  $view_config->add_form_element({
    name   => 'pairwise_blastz',
    label  => 'BLASTz net pairwise alignments',
    type   => 'YesNo',
    select => 'select'
  });

  $view_config->add_form_element({
    name   => 'pairwise_tblat',
    label  => 'Trans. BLAT net pairwise alignments',
    type   => 'YesNo',
    select => 'select'
  });
  
  $view_config->add_form_element({
    name   => 'pairwise_align',
    label  => 'Pairwise alignments',
    type   => 'YesNo',
    select => 'select'
  });
}

1;
