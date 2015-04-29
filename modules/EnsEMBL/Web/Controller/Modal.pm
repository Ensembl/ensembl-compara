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

package EnsEMBL::Web::Controller::Modal;

use strict;

use base qw(EnsEMBL::Web::Controller::Page);

sub page_type { return 'Popup'; }
sub request   { return 'modal'; }

sub init {
  my $self = shift;

  $self->builder->create_objects unless $self->page_type eq 'Configurator' && !scalar grep $_, values %{$self->hub->core_params};
  $self->renderer->{'_modal_dialog_'} = $self->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest' || $self->hub->param('X-Requested-With') eq 'iframe'; # Flag indicating that this is modal dialog panel, loaded by AJAX/hidden iframe
  $self->page->initialize; # Adds the components to be rendered to the page module
  $self->configure;
  $self->render_page;
}

1;
