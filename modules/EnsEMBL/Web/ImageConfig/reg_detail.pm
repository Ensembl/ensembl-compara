# $Id$

package EnsEMBL::Web::ImageConfig::reg_detail;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title     => 'Feature context',
    opt_lines => 1,
  });  
  
  $self->create_menus(qw(
    sequence
    transcript
    prediction
    dna_align_rna
    oligo
    simple
    misc_feature
    repeat
    functional
    multiple_align
    variation
    other
    information
  ));
  
  $self->add_tracks('other',
    [ 'draggable',                '', 'draggable',                { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque' }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );
  $self->modify_configs(
    [ 'alignment_compara_431_constrained' ], 
    { display => 'compact' }
 ); 
 $self->modify_configs(
    [ 'functional' ],
    { display => 'normal' }
  );
  $self->modify_configs(
    [ 'gene_legend' ],
    { display => 'off' }
  );

  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS');
  
  $self->modify_configs(
    [ map "regulatory_regions_funcgen_$_", @feature_sets ],
    { depth => 25, height => 6 }
  );
  
  my @cell_lines = map s/\:\d*//, sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  
  foreach my $cell_line (@cell_lines) { 
    $cell_line =~ s/\:\d*//;
    
    # Turn off core and supporting evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line", "reg_feats_other_$cell_line" ],
      { display => 'off' }
    );
  }
}

1;
