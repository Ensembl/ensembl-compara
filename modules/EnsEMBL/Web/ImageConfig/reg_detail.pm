package EnsEMBL::Web::ImageConfig::reg_detail;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title         => 'Feature context',
    show_buttons  => 'no',
    show_labels   => 'yes',
    label_width   => 113,
    opt_lines     => 1,
    margin        => 5,
    spacing       => 2,
  });  

  $self->create_menus(
    sequence       => 'Sequence',
    transcript     => 'Genes',
    prediction     => 'Prediction transcripts',
    dna_align_rna  => 'RNA alignments',
    oligo          => 'Probe features',
    simple         => 'Simple features',
    misc_feature   => 'Misc. regions',
    repeat         => 'Repeats',
    functional     => 'Functional Genomics', 
    multiple_align => 'Multiple alignments',
    variation      => 'Variation',
    other          => 'Decorations',
    information    => 'Information'
  );

  $self->add_tracks('other',
    [ 'fg_wiggle',                '', 'fg_wiggle',                { display => 'tiling', strand => 'r', menu => 'no', colourset => 'feature_set' }],
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'b', menu => 'no', colours => 'bisque' }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [ 'fg_regulatory_features_funcgen_reg_feats' ],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );
  
  $self->modify_configs(
    [ 'alignment_compara_431_constrained' ], 
    { display => 'compact' }
 ); 

}
1;
