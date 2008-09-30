package EnsEMBL::Web::ImageConfig::contigviewtop;

use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Overview panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'    => 1, # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks'  => 0, # include empty tracks..
    'opt_lines'         => 1, # draw registry lines
    'opt_restrict_zoom' => 1, # when we get "zoom" working draw restriction enzyme info on it!!

## Finally some colours... background image colors;
## and alternating colours for tracks...
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background2',
    'bgcolour2'     => 'background3',
  });

  $self->create_menus(
    'sequence'    => 'Sequence',
    'marker'      => 'Markers',
    'gene'        => 'Genes',
#    'misc_set'    => 'Misc. regions',
    'synteny'     => 'Synteny',
#    'user_data'   => 'User uploaded data',
    'other'       => 'Additional features',
    'information' => 'Information',
    'options'     => 'Options'
  );

  $self->add_track( 'sequence',    'contig',    'Contigs',             'stranded_contig', { 'display' => 'normal', 'strand' => 'f' } );
  $self->add_track( 'information', 'info',      'Information',         'text',            { 'display' => 'normal'  } );
  
  $self->load_tracks();

  $self->add_tracks( 'other',
    [ 'scalebar',  '', 'scalebar',  { 'display' => 'normal'  }],
    [ 'ruler',     '', 'ruler',     { 'display' => 'normal', 'strand' => 'f'  }],
    [ 'draggable', '', 'draggable', { 'display' => 'normal', 'menu' => 'no' }]
  );
  
  $self->add_options(
    ['opt_halfheight',     'Half height glyphs',  {qw(1 Yes 0 No)} ],
    ['opt_register_lines', 'Show register lines', {qw(1 Yes 0 No)} ]
  );
}

1;
