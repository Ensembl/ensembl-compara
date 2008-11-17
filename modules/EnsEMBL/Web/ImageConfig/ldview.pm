package EnsEMBL::Web::ImageConfig::ldview;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift; 

  $self->set_parameters({
    '_userdatatype_ID'    =>  30,
    '_transcript_names_'  =>  'yes',
    'title'         => 'LD slice',
    'show_buttons'  => 'no',    # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing
    'image_width'   => 800,
    'context'       => 20000,
  });

  $self->create_menus(
    'transcript'      => 'Other Genes',
    'prediction'      => 'Prediction transcripts',
    'other'           => 'Other',
    'variation'       => 'Variations',
    'legends'         => 'Legends',
  );

  $self->load_tracks();

  $self->modify_configs(
    [qw(variation_feature_genotyped_variation)],
    {qw(display normal), 'strand' => 'r', 'style' => 'box', 'depth' => 10000 }
  );

  $self->add_tracks( 'other',
    [ 'ruler',                  '',     'ruler',      { 'display' => 'normal',  'strand' => 'f', 'name' => 'Ruler'  } ],
    [ 'scalebar',               '',     'scalebar',   { 'display' => 'normal', 'strand' => 'r', 'name' => 'Scale bar' } ],
  );

  $self->add_tracks( 'legends',
    [ 'variation_legend',                  '',     'variation_legend',      { 'variation_legend' => 'on',  'strand' => 'r', 'caption' => 'Variation legend'  } ],
  );

  $self->modify_configs(
    [qw(transcript_core_ensembl)],
    {qw(display normal)}
  );
  $self->modify_configs(
    [qw(variation_feature_variation)],
    {qw(display normal), 'caption' => 'Variations', 'strand' => 'r',}
  );

}
1;

