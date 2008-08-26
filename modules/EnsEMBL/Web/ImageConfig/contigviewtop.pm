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
    'misc_set'    => 'Misc. regions',
    'repeat'      => 'Repeats',
    'synteny'     => 'Synteny',
    'user_data'   => 'User uploaded data',
    'other'       => 'Additional features',
    'options'     => 'Options'
  );

  $self->add_track( 'sequence', 'contig',    'Contigs',             'strandard_contig', { 'on' => 'on'  } );
  $self->add_track( 'info',     'info',      'Information',         'info',             { 'on' => 'on'  } );
  
  $self->load_tracks();

  $self->add_track( 'other',    'scalebar',  'Scale bar',           'scalebar',         { 'on' => 'on'  } );
  $self->add_track( 'other',    'ruler',     'Ruler',               'ruler',            { 'on' => 'on'  } );
  $self->add_track( 'other',    'draggable', 'Drag region',         'draggable',        { 'on' => 'on', 'menu' => 'no' } );
  
  $self->set_options({
    'opt_halfheight'     => { 'caption' => 'Half height glyphs',  'values' => {qw(1 Yes 0 No)} },
    'opt_register_lines' => { 'caption' => 'Show register lines', 'values' => {qw(1 Yes 0 No)} }
  });
}

1;
