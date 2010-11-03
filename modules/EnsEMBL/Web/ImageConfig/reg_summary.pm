package EnsEMBL::Web::ImageConfig::reg_summary;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title        => 'Feature context',
    show_buttons => 'no',
    show_labels  => 'yes',
    label_width  => 113,
    opt_lines    => 1,
    margin       => 5,
    spacing      => 2,
  });  

  $self->create_menus(
    sequence      => 'Sequence',
    transcript    => 'Genes',
    prediction    => 'Prediction transcripts',
    dna_align_rna => 'RNA alignments',
    oligo         => 'Probe features',
    simple        => 'Simple features',
    misc_feature  => 'Misc. regions',
    repeat        => 'Repeats',
    functional    => 'Functional Genomics', 
    variation     => 'Germline variation',
    other         => 'Decorations',
    information   => 'Information'
  );

  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks;
  $self->load_configured_das;
  
  $self->modify_configs(
    [ 'functional' ],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_nolabel' }
  );

  # Turn off cell line wiggle tracks
  my @cell_lines =  sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  foreach my $cell_line (@cell_lines){
    $cell_line =~s/\:\d*//;
    # Turn on core evidence track
    $self->modify_configs(
      [ 'reg_feats_core_' .$cell_line ],
      { qw(display off)}
    );
    # Turn on supporting evidence track
    $self->modify_configs(
      [ 'reg_feats_other_' .$cell_line ],
      {qw(display off)}
    );
  }
}

1;
