package EnsEMBL::Web::ImageConfig::generegview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift; 
  my $fset = $self->cache('feature_sets'); 

  $self->set_parameters({
 
    title         => 'Regulation Image',
    show_buttons  => 'no',  # do not show +/- buttons
    show_labels   => 'yes',  # show track names on left-hand side
    label_width   => 113,   # width of labels on left-hand side
    opt_lines     => 1,     # draw registry lines
    margin        => 5,     # margin
    spacing       => 2,     # spacing
  });

  $self->create_menus(
    transcript          => 'Genes',
    prediction          => 'Prediction transcripts',
    functional          => 'Functional genomics',
    other               => 'Decorations',
    information         => 'Information',
  );

  $self->load_tracks();
 
  $self->add_tracks( 'other',
    [ 'ruler',     '',  'ruler',          { display => 'normal', strand => 'r', name => 'Ruler',  description => 'Shows the length of the region being displayed' } ],
    [ 'draggable', '',  'draggable',      { display => 'normal', strand => 'b', menu => 'no' } ],
    [ 'scalebar',  '',  'scalebar',       { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }],
  );

  $self->modify_configs(
    [qw(functional)],
    {qw(display normal)}
  );
  $self->modify_configs(
    [qw(ctcf_funcgen_Nessie_NG_STD_2)],
    {qw(display tiling)}
  );
  $self->modify_configs(
    [qw(ctcf_funcgen_blocks_Nessie_NG_STD_2)],
    {qw(display compact)}
  );
  $self->modify_configs(
    [qw(histone_modifications_funcgen_VSN_GLOG)],
    {qw(display tiling)}
  );
  $self->modify_configs(
    [qw(gene_legend)],
    {qw(display off)}
  );
  $self->modify_configs(
    [qw(transcript_core_ensembl)],
    {qw(display transcript_label)}
  );
}
1;

