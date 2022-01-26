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

package EnsEMBL::Web::Template::Legacy::AltNav;

### Legacy page template, used by pages with custom LH menu e.g. Solr search 

use parent qw(EnsEMBL::Web::Template::Legacy);

sub init {
  my $self = shift;
  $self->{'main_class'}       = 'main';
  $self->{'lefthand_menu'}    = 0;
  $self->{'has_species_bar'}  = 0;
  $self->{'has_tabs'}         = $self->hub->controller->configuration->has_tabs;
  $self->add_head;
  $self->add_body;
}

1;
