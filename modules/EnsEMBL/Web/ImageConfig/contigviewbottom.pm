package EnsEMBL::Web::ImageConfig::contigviewbottom;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init_user {
  my $self = shift;
  return $self->load_user_tracks;
}

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title             => 'Main panel',
    show_buttons      => 'no',  # show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_halfheight    => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1      # when we get "zoom" working draw restriction enzyme info on it
  });
  
  # First add menus in the order you want them for this display
  $self->create_menus(
    sequence         => 'Sequence',
    marker           => 'Markers',
    trans_associated => 'Transcript Features',
    transcript       => 'Genes',
    prediction       => 'Prediction Transcripts',
    protein_align    => 'Protein alignments',
    protein_feature  => 'Protein features',
    dna_align_cdna   => 'cDNA/mRNA alignments', # Separate menus for different cDNAs/ESTs
    dna_align_est    => 'EST alignments',
    dna_align_rna    => 'RNA alignments',
    dna_align_other  => 'Other DNA alignments', 
    oligo            => 'Probe features',
    ditag            => 'Ditag features',
    external_data    => 'External data',
    user_data        => 'User attached data', # DAS/URL tracks/uploaded data/blast responses
    simple           => 'Simple features',
    misc_feature     => 'Misc. regions',
    repeat           => 'Repeats',
    variation        => 'Variation features',
    functional       => 'Functional genomics',
    multiple_align   => 'Multiple alignments',
    pairwise_blastz  => 'BLASTZ alignments',
    pairwise_tblat   => 'Translated blat alignments',
    pairwise_other   => 'Pairwise alignment',
    decorations      => 'Additional decorations',
    information      => 'Information'
  );
  
  # Note these tracks get added before the "auto-loaded tracks" get added
  $self->add_tracks( 'sequence', 
    [ 'contig',    'Contigs',             'stranded_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' }],
    [ 'seq',       'Sequence',            'sequence',        { display => 'off',    strand => 'b', threshold => 0.2, colourset => 'seq',      description => 'Track showing sequence in both directions' }],
    [ 'codon_seq', 'Translated sequence', 'codonseq',        { display => 'off',    strand => 'b', threshold => 0.5, colourset => 'codonseq', description => 'Track showing 6-frame translation of sequence' }],
    [ 'codons',    'Start/stop codons',   'codons',          { display => 'off',    strand => 'b', threshold => 50,  colourset => 'codons',   description => 'Track indicating locations of start and stop codons in region' }],
    [ 'blast',     'BLAT/BLAST hits',     '_blast',          { display => 'normal', strand => 'b', sub_type => 'blast', colourset => 'feature', menu => 'no' }]
  );
  
  $self->add_track('decorations', 'gc_plot', '%GC', 'gcplot', { display => 'normal',  strand => 'r', description => 'Shows %age of Gs & Cs in region' });
  
  if ($self->species_defs->ALTERNATIVE_ASSEMBLIES) {
    foreach my $alt_assembly (@{$self->species_defs->ALTERNATIVE_ASSEMBLIES}) {
      $self->add_track('misc_feature', "${alt_assembly}_assembly", "$alt_assembly assembly", 'alternative_assembly', { 
        display       => 'off', 
        strand        => 'f', 
        colourset     => 'alternative_assembly', 
        description   => "Track indicating $alt_assembly assembly", 
        assembly_name => $alt_assembly 
      });
    }
  }
  
  # show versions of clones from other sites
  if ($self->species_defs->das_VEGACLONES) {
    $self->add_track('misc_feature', 'v_clones', 'Vega clones', 'alternative_clones', { 
      display     => 'off', 
      strand      => 'f', 
      description => 'Vega clones', 
      colourset   => 'alternative_clones', 
      das_source  => 'das_VEGACLONES'
    });
  }
  
  if ($self->species_defs->das_ENSEMBLCLONES) {
    $self->add_tracks('misc_feature', 'e_clones', 'Ensembl clones', 'alternative_clones', { 
      display     => 'off', 
      strand      => 'f', 
      description => 'Ensembl clones', 
      colourset   => 'alternative_clones', 
      das_source  => 'das_ENSEMBLCLONES'
    });
  }
  
  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_das;
  
  # These tracks get added after the "auto-loaded tracks get addded
  if ($self->species_defs->ENSEMBL_MOD) {
    $self->add_track('information', 'mod', '', 'text', {
      name    => 'Message of the day',
      display => 'normal',
      menu    => 'no',
      strand  => 'r', 
      text    => $self->species_defs->ENSEMBL_MOD
    })
  }

  $self->add_tracks('information',
    [ 'missing',   '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary', description => 'Show counts of number of tracks turned off by the user' }],
    [ 'info',      '', 'text', { display => 'normal', strand => 'r', name => 'Information',            description => 'Details of the region shown in the image' }]
  );
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Track' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

1;
