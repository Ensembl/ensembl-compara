package EnsEMBL::Web::ImageConfig::regulation_view;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title          => 'Feature context',
    show_buttons   => 'no',
    show_labels    => 'yes',
    label_width    => 113,
    opt_lines      => 1,
    margin         => 5,
    spacing        => 2,
    opt_highllight => 'yes',
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
  );

  $self->add_tracks('other',
    [ 'scalebar',   '', 'scalebar',   { display => 'normal', strand => 'f', name => 'Scale bar', menu => 'no' }],
    [ 'ruler',      '', 'ruler',      { display => 'normal', strand => 'f', name => 'Ruler', menu => 'no' }],
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', tag => 0, strand => 'r', menu => 'no',}],
);
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [ 'functional' ],
    { display => 'off', menu => 'no' }
  );
  $self->modify_configs(
    [qw(ctcf_funcgen_Nessie_NG_STD_2)],
    {qw(menu yes)}
  );
  $self->modify_configs(
    [qw(ctcf_funcgen_blocks_Nessie_NG_STD_2)],
    {qw(menu yes)}
  );
  $self->modify_configs(
    [qw(regulatory_regions_funcgen_feature_set)],
    {qw(menu yes)}
  );
  $self->modify_configs(
    [qw(regulatory_regions_funcgen_search)],
    {qw(menu yes)}
  ); 
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );

}
1;
