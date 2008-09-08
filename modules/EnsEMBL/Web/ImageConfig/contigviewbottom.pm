package EnsEMBL::Web::ImageConfig::contigviewbottom;
use strict;
no strict 'refs';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self ) = @_;

  $self->set_parameters({
    'title'         => 'Detailed panel',
    'show_buttons'  => 'yes',   # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
    'opt_lines'        => 1,    # draw registry lines
    'opt_restrict_zoom' => 1,   # when we get "zoom" working draw restriction enzyme info on it!!

## Finally some colours... background image colors;
## and alternating colours for tracks...
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background2',
    'bgcolour2'     => 'background3',
  });

## First add menus in the order you want them for this display....
  $self->create_menus(
    'sequence'        => 'Sequence',
    'marker'          => 'Markers',
    'transcript'      => 'Genes',
    'prediction'      => 'Prediction Transcripts',
    'protein_align'   => 'Protein alignments',
    'dna_align_cdna'  => 'cDNA/mRNA alignments', # Separate menus for different cDNAs/ESTs...
    'dna_align_est'   => 'EST alignments',
    'dna_align_rna'   => 'RNA alignments',
    'dna_align_other' => 'Other DNA alignments', 
    'oligo'           => 'Oligo features',
    'ditag'           => 'Ditag features',
    'simple'          => 'Simple features',
    'misc_feature'    => 'Misc. regions',
    'repeat'          => 'Repeats',
    'variation'       => 'Variaton features',
    'functional'      => 'Functional genomics',
    'multiple_align'  => 'Multiple alignments',
    'pairwise_blastz' => 'BLASTZ alignments',
    'pairwise_tblat'  => 'Translated blat alignments',
    'pairwise_other'  => 'Pairwise alignment',
    'user_data'       => 'User uploaded data', # DAS/URL tracks/uploaded data/blast responses
    'other'           => 'Additional decorations',
    'information'     => 'Information',
    'options'         => 'Options'
  );


## Note these tracks get added before the "auto-loaded tracks" get added...
  $self->add_tracks( 'sequence', 
    [ 'contig',    'Contigs',              'stranded_contig', { 'on' => 'on',  'strand' => 'r'  } ],
#   [ 'prelim',    'Preliminary release', 'preliminary',      { 'on' => 'off', 'menu' => 'no',  'strand' => 'r' } ],
    [ 'seq',       'Sequence',             'seq',             { 'on' => 'off',  'strand' => 'r' } ],
    [ 'codon_seq', 'Translated sequence',  'codonseq',        { 'on' => 'off',  'strand' => 'r' } ],
    [ 'codons',    'Start/stop codons',    'codons',          { 'on' => 'off',  'strand' => 'r' } ],
  );
  $self->add_tracks( 'other', 
    [ 'gc_plot',   '%GC',                  'gcplot',          { 'on' => 'on',  'strand' => 'r'  } ],
  );
  
## Add in additional
  $self->load_tracks();

#  foreach ( $self->get_node('variation')->descendants ) { $_->set('style','box'); $_->set('depth',2000); $_->set('bump_Width',1); }

## These tracks get added after the "auto-loaded tracks get addded...
  if( $self->species_defs->ENSEMBL_MOD ) {
    $self->add_track( 'information', 'mod', '', 'text', { 'name' => 'Message of the day', 'on' => 'on', 'menu' => 'no', 'strand' => 'r', 'text' => $self->species_defs->ENSEMBL_MOD } )
  }
  $self->add_tracks( 'information',
    [ 'missing',   '', 'missing',         { 'on' => 'on',  'strand' => 'r', 'name' => 'Disabled track summary'  } ],
    [ 'info',      '', 'info',            { 'on' => 'on',  'strand' => 'r', 'name' => 'Information'  } ],
  );
  $self->add_tracks( 'other',  
    [ 'scalebar',  '',            'scalebar',        { 'on' => 'on',  'strand' => 'b', 'name' => 'Scale bar'  } ],
    [ 'ruler',     '',            'ruler',           { 'on' => 'on',  'strand' => 'b', 'name' => 'Ruler'      } ],
    [ 'draggable', '',            'draggable',       { 'on' => 'on',  'strand' => 'b', 'menu' => 'no'         } ],
  );

## Finally add details of the options to the options menu...
  $self->add_options(
    [ 'opt_halfheight',    'Half height glyphs?'          ],
    [ 'opt_empty_tracks',  'Show empty tracks?'           ],
    [ 'opt_lines',         'Show registry lines?'         ],
    [ 'opt_restrict_zoom', 'Restriction enzymes on zoom?' ],
  );
}

1;
