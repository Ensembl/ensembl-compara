package EnsEMBL::Web::ImageConfig::snpview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title             => 'Variation Context',
    show_buttons      => 'no',  # do not show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_halfheight    => 1,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,     # draw registry lines
  });
  
  $self->create_menus(
    transcript  => 'Genes',
    prediction  => 'Prediction transcripts',
    sequence    => 'Sequence',
    variation   => 'Germline Variation',
    somatic     => 'Somatic Mutation',
    functional  => 'Functional Genomics',
    information => 'Information', 
    other       => 'Decorations'
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->add_tracks('information',
    [ 'variation_legend', '', 'variation_legend', { display => 'normal', strand => 'r', name => 'Variation Legend', caption => 'Variation legend' }]
  );
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );

  $self->load_tracks;

  $self->modify_configs(
    [ 'variation' ],
    { style => 'box', depth => 100000 }
  );
 
  $self->modify_configs(
   [ 'gene_legend' ],
   { display => 'off', menu => 'no' }
  );

  # variations
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal' }
  );  
  $self->modify_configs(
    ['variation_set_Phenotype-associated variations'],
    { display => 'normal' }
  );
  $self->modify_configs(
    ['variation_feature_structural'],
    { display => 'normal', depth => 10 }
  );
    $self->modify_configs(
    ['somatic_mutation_COSMIC'],
    { display => 'normal', style => 'box', depth => 100000 }
  );

  
  # genes
  $self->modify_configs(
    ['transcript_core_ensembl'],
    { display => 'transcript_nolabel' }
  );
  
  # reg feats
  $self->modify_configs(
    [qw(functional)],
    {qw(display normal)}
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
