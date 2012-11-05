# $Id$

package EnsEMBL::Web::ImageConfig::generegview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift; 

  $self->set_parameters({
    sortable_tracks => 1,  # allow the user to reorder tracks
    opt_lines       => 1,  # draw registry lines
  });

  $self->create_menus(qw(
    transcript
    prediction
    functional
    other
    information
  ));

  $self->load_tracks;
 
  $self->add_tracks('other',
    [ 'ruler',     '',  'ruler',     { display => 'normal', strand => 'r', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '',  'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'scalebar',  '',  'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }],
  );

  $self->modify_configs(
    [ 'regulatory_features', 'functional_other_regulatory_regions' ],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [ 'regulatory_features_core', 'regulatory_features_other' ],
    { display => 'off', menu => 'no' }
  );
  
  # hack to stop zmenus having the URL ZMenu/Transcript/Regulation, since this causes a ZMenu::Regulation to be created instead of a ZMenu::Transcript
  $_->data->{'zmenu'} ||= 'x' for $self->get_node('transcript')->nodes;
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );
  
  $self->modify_configs(
    [ 'regulatory_regions_funcgen_feature_set' ],
    { depth => 25, height => 6 }
  );
  
  $self->load_configured_das('functional');
}

1;
