=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Export::Configure;

use strict;

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $hub->get_viewconfig({component => 'Export', type => $hub->function, cache => 1});
  
  $view_config->build_form($self->object);
  
  my $form = $view_config->form;
  
  $form->set_attribute('method', 'post');
 
  my $tip = $hub->function eq 'Location' ? '' : $self->_info('Tip', 'For sequence export, please go to the relevant sequence page (see lefthand menu) and use the new "Download sequence" button');
 
  return '<h2>Export Configuration - Feature List</h2>' . $tip . $form->render;
}

1;
