package EnsEMBL::Web::ImageConfig::gene_summary;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    'title'         => 'Transcript panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
  });

  $self->create_menus(
    'sequence'   => 'Sequence',
    'transcript' => 'Other genes',
    'prediction' => 'Prediction transcripts',
    'variation'  => 'Variaton features',
    'functional' => 'Functional genomics',
    'other'      => 'Decorations',
  );

  $self->add_tracks( 'other',
    [ 'scalebar',  '',            'scalebar',        { 'display' => 'normal',  'strand' => 'b', 'name' => 'Scale bar'  } ],
    [ 'ruler',     '',            'ruler',           { 'display' => 'normal',  'strand' => 'b', 'name' => 'Ruler'      } ],
    [ 'draggable', '',            'draggable',       { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
  );
  $self->add_tracks( 'sequence',
    [ 'contig',    'Contigs',              'stranded_contig', { 'display' => 'normal',  'strand' => 'r'  } ],
  );

  $self->load_tracks;

  $self->modify_configs(
    [qw(transcript prediction variation)],
    {qw(display off)} 
  );

}
1;

