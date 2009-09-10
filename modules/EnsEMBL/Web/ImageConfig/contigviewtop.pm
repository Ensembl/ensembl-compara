package EnsEMBL::Web::ImageConfig::contigviewtop;

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
    title             => 'Top panel',
    show_buttons      => 'no',  # do not show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_empty_tracks  => 0,     # include empty tracks
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1      # when we get "zoom" working draw restriction enzyme info on it
  });
  
  $self->create_menus(
    sequence    => 'Sequence',
    marker      => 'Markers',
    transcript  => 'Genes',
    synteny     => 'Synteny',
    decorations => 'Additional features',
    information => 'Information'
  );
  
  $self->add_track('sequence',    'contig', 'Contigs',     'stranded_contig', { display => 'normal', strand => 'f' });
  $self->add_track('information', 'info',   'Information', 'text',            { display => 'normal' });
  
  $self->load_tracks;
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', menu => 'no' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', menu => 'no', strand => 'f' }],
    [ 'draggable', '', 'draggable', { display => 'normal', menu => 'no' }]
  );
  
  $self->modify_configs(
    [ 'transcript' ],
    { qw(render gene_label strand r) }
  );
}

1;
