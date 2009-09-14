package EnsEMBL::Web::ImageConfig::alignsliceviewbottom;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub mergeable_config {
  return 1;
}

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title         => 'Detailed panel',
    show_buttons  => 'no',  # do not show +/- buttons
    button_width  => 8,     # width of red "+/-" buttons
    show_labels   => 'yes', # show track names on left-hand side
    label_width   => 113,   # width of labels on left-hand side
    margin        => 5,     # margin
    spacing       => 2      # spacing
  });

  $self->create_menus(
    sequence    => 'Sequence',
    transcript  => 'Genes',
    repeat      => 'Repeats',
    variation   => 'Variation features',
    information => 'Information'
  );
  
  $self->add_track('sequence', 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' });
  
  $self->add_tracks('information', 
    [ 'alignscalebar',     '',                  'alignscalebar',     { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'ruler',             '',                  'ruler',             { display => 'normal', strand => 'f', menu => 'no' }],
#   [ 'draggable',         '',                  'draggable',         { display => 'normal', strand => 'b', menu => 'no' }], # TODO: get this working
    [ 'alignslice_legend', 'AlignSlice Legend', 'alignslice_legend', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks;
  
  $self->modify_configs(
    [ 'transcript' ],
    { renderers => [ 
        off                   => 'Off', 
        as_transcript_label   => 'Expanded with labels',
        as_transcript_nolabel => 'Expanded without labels',
        as_collapsed_label    => 'Collapsed with labels',
        as_collapsed_nolabel  => 'Collapsed without labels' 
    ]}
  );
}

1;
