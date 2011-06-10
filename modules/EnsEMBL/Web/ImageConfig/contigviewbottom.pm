# $Id$

package EnsEMBL::Web::ImageConfig::contigviewbottom;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init_user {
  my $self = shift;
  return $self->load_user_tracks;
}

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title             => 'Main panel',
    sortable_tracks   => 'drag', # allow the user to reorder tracks on the image
    opt_halfheight    => 0,      # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,      # draw registry lines
    opt_restrict_zoom => 1       # when we get "zoom" working draw restriction enzyme info on it
  });
  
  # First add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    trans_associated
    transcript
    prediction
    protein_align
    protein_feature
    dna_align_cdna
    dna_align_est
    dna_align_rna
    dna_align_other
    rnaseq
    oligo
    ditag
    external_data
    user_data
    simple
    misc_feature
    repeat
    variation
    somatic
    functional
    multiple_align
    pairwise_blastz
    pairwise_tblat
    pairwise_other
    decorations
    information
  ));
  
  # Note these tracks get added before the "auto-loaded tracks" get added
  $self->add_tracks( 'sequence', 
    [ 'contig',    'Contigs',             'stranded_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' }],
    [ 'seq',       'Sequence',            'sequence',        { display => 'off',    strand => 'b', bump_width => 0, threshold => 0.2, colourset => 'seq',      description => 'Track showing sequence in both directions' }],
    [ 'codon_seq', 'Translated sequence', 'codonseq',        { display => 'off',    strand => 'b', bump_width => 0, threshold => 0.5, colourset => 'codonseq', description => 'Track showing 6-frame translation of sequence' }],
    [ 'codons',    'Start/stop codons',   'codons',          { display => 'off',    strand => 'b', threshold => 50,  colourset => 'codons',   description => 'Track indicating locations of start and stop codons in region' }],
    [ 'blast',     'BLAT/BLAST hits',     '_blast',          { display => 'normal', strand => 'b', sub_type => 'blast', colourset => 'feature', menu => 'no' }]
  );
  
  $self->add_track('decorations', 'gc_plot', '%GC', 'gcplot', { display => 'normal',  strand => 'r', description => 'Shows percentage of Gs & Cs in region', sortable => 1 });
  
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
    $self->add_track('misc_feature', 'e_clones', 'Ensembl clones', 'alternative_clones', {
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
#  $self->load_configured_bam;
  
  # These tracks get added after the "auto-loaded tracks get addded
  if ($self->species_defs->ENSEMBL_MOD) {
    $self->add_track('information', 'mod', '', 'text', {
      name    => 'Message of the day',
      display => 'normal',
      menu    => 'no',
      strand  => 'r', 
      text    => $self->species_defs->ENSEMBL_MOD
    });
  }

  $self->add_tracks('information',
    [ 'missing', '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary', description => 'Show counts of number of tracks turned off by the user' }],
    [ 'info',    '', 'text', { display => 'normal', strand => 'r', name => 'Information',            description => 'Details of the region shown in the image' }]
  );
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  # switch on default compara multiple alignments (check track name each release)
  $self->modify_configs(
    [ 'alignment_compara_436_scores' ],
    { display => 'tiling' }
  );
  $self->modify_configs(
    [ 'alignment_compara_436_constrained' ],
    { display => 'compact' }
  );

  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS');
  
  foreach my $f_set (@feature_sets) {
    $self->modify_configs(
      [ "regulatory_regions_funcgen_$f_set" ],
      { depth => 25, height => 6 }
    );
  }
  
  # Enable cell line displays 
  my @cell_lines = sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  
  foreach my $cell_line (@cell_lines) {
    $cell_line =~ s/\:\d*//;
    
    # Turn on menus for core and supporting evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line", "reg_feats_other_$cell_line" ],
      { menu => 'yes' }
    );
  }
}

1;
