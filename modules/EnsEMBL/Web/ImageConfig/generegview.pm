=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  $self->image_resize = 1;
 
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
    [ 'regulatory_features_core', 'regulatory_features_non_core' ],
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
