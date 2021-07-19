=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::ModalTabs;

# Generates the global context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element::Tabs EnsEMBL::Web::Document::Element::Modal);

sub init {
  my $self       = shift;
  my $controller = shift;
  my $hub        = $self->hub;
  my $type       = $controller->page_type eq 'Configurator' ? 'Config' : $hub->type;
  my $config     = 'config_' . $hub->action;
  
  $self->EnsEMBL::Web::Document::Element::Modal::init($controller);
  
  foreach (@{$self->entries}) {
    if (($type eq 'Config' && $_->{'id'} eq $config) || ($type eq 'UserData' && $_->{'id'} eq 'user_data')) {
      $_->{'class'} = 'active';
      $self->active('modal_' . lc $_->{'id'});
      last;
    }
  }
}

sub get_json {
  my $self    = shift;
  my $content = $self->content;
  return $content ? { tabs => $content, activeTab => $self->active } : {};
}

1;
