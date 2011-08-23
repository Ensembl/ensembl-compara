# $Id$

package EnsEMBL::Web::ImageConfig::hsp_query_plot;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    label_width => 80, # width of labels on left-hand side
  });

  $self->create_menus('other');

  $self->add_tracks('other',
    [ 'scalebar',   '',         'HSP_scalebar',   { display => 'normal', strand => 'f', name => 'Scale bar',      col => 'black', description => 'Shows the scalebar' }],
    [ 'query_plot', 'HSPs',     'HSP_query_plot', { display => 'normal', strand => 'b', name => 'HSP Query Plot', col => 'red', dep => 50, txt => 'black', mode => 'allhsps' }],
    [ 'coverage',   'coverage', 'HSP_coverage',   { display => 'normal', strand => 'f', name => 'HSP Coverage' }]
  );
  
  $self->storable = 0;
}

1;
