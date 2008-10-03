package EnsEMBL::Web::ImageConfig::hsp_query_plot;
use strict;
use base qw( EnsEMBL::Web::ImageConfig );

sub init {
  my ($self) = shift;

  $self->set_parameters({
   'title'         => 'Alignment panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
  });

  $self->create_menus(
    'other'      => 'Decorations',
    'alignments' => 'Alignment',
  );

  $self->add_tracks( 'other',
    [ 'scalebar',  '',            'HSP_scalebar',        { 'display' => 'normal',  'strand' => 'f', 'name' => 'Scale bar', 'col' => 'black', 'pos' => 11  } ],
  );

  $self->add_tracks('alignments',
    ['query_plot',    '+ hsps',     'HSP_query_plot', {'display' => 'normal',  'strand' => 'b', 'name' => 'HSP Query Plot', 'dep' => 50, 'txt' => 'black', 'col' => 'red', 'mode' => 'allhsps', 'pos' => 30}],  
    ['coverage',    'coverage',       'HSP_coverage',   {'display' => 'normal',  'strand' => 'f', 'name' => 'HSP Coverage', 'pos' => 20}],  
  );

}
1;
