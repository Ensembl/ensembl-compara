package EnsEMBL::Web::ImageConfig::gene_sv_view;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    opt_lines => 1, # draw registry lines
  });

  $self->create_menus(qw(
    sequence
    transcript
    prediction
    variation
    somatic
    functional
    external_data
    user_data
    other
  ));

  $self->add_tracks('other',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs',  'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [ 'fg_regulatory_features_funcgen', 'transcript', 'prediction', 'variation' ],
    { display => 'off' }
  );
  
  $self->modify_configs(	 
    [ 'transcript_core_ensembl', 'transcript_core_sg' ],
    { display => 'transcript_label' }
  );
	
	# structural variations
	$self->modify_configs(
    ['variation_feature_structural'],
    { display => 'normal', depth => 50 }
  );
  
  $self->storable = 0;
}

1;
