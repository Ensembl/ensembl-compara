=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::chromosome;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    label_width => 130, # width of labels on left-hand side
  });
  
  $self->{'extra_menus'} = { display_options => 1 };
  
  $self->create_menus('decorations');
  
  $self->add_tracks('decorations', 
    [ 'ideogram', 'Ideogram', 'ideogram',  { display => 'normal', menu => 'no', strand => 'r', colourset => 'ideogram' }],
  );
  
  $self->load_tracks;
  
  $self->add_tracks('decorations',
    [ 'draggable', '', 'draggable', { display => 'normal', menu => 'no' }]
  );
  
  $self->get_node('decorations')->set('caption', 'Decorations');
  
  $self->modify_configs(
    [ 'decorations' ],
    { short_labels => 1 }
  );
}

1;
