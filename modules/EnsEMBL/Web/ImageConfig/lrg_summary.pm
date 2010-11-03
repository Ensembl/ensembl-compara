package EnsEMBL::Web::ImageConfig::lrg_summary;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);
use Data::Dumper;

sub init {
  my $self = shift;

  $self->set_parameters({
    title         => 'Transcript panel',
    show_buttons  => 'no',  # do not show +/- buttons
    show_labels   => 'yes', # show track names on left-hand side
    label_width   => 113,   # width of labels on left-hand side
    opt_lines     => 1,     # draw registry lines
    margin        => 5,     # margin
    spacing       => 2,     # spacing
  });

  $self->create_menus(
    sequence      => 'Sequence',
    transcript    => 'Other genes',
    prediction    => 'Prediction transcripts',
    lrg           => 'LRG transcripts',
    variation     => 'Germline variation',
    somatic       => 'Somatic mutations',
    functional    => 'Functional genomics',
    external_data => 'External data',
    user_data     => 'User attached data', # DAS/URL tracks/uploaded data/blast responses
    other         => 'Decorations',
  );

  $self->add_tracks('other',
    [ 'scalebar',  '', 'lrg_scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs',  'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;
  $self->load_configured_das;

  $self->add_tracks('lrg',
    [ 'lrg_transcript',  'LRG', '_transcript',
      { display       => 'normal',
	      name          => 'LRG transcripts', 
	      description   => 'Shows LRG transcripts',
	      logicnames    => ['LRG_import'], 
	      logic_name    => 'LRG_import',
        'colours'     => $self->species_defs->colour( 'gene' ),
        'label_key'   => '[display_label]',
	      'colour_key'  => '[logic_name]',
	      'zmenu'       => 'LRG',
      }],
  );

  $self->modify_configs(
    [qw(fg_regulatory_features_funcgen)],
    {qw(display off)}
  );
  $self->modify_configs(
    [qw(transcript prediction variation)],
    {qw(display off)} 
  );
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal' }
  );

  $self->modify_configs(
    [qw(transcript_core_ensembl)],
    {qw(display transcript_label)}
  );

}

1;
