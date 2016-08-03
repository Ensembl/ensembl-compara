=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::Export;

use strict;

use base qw(EnsEMBL::Web::Controller::Page);
 
sub page_type { return $_[0]->action eq 'Output' ? 'Dynamic' : 'Popup'; }
sub request   { return $_[0]->action eq 'Output' ? 'Export'  : 'Modal'; }

sub init {
  my $self = shift;
  
  $self->hub->type = $self->hub->function if $self->hub->action eq 'Output';    #this is to get the left nav and top nav according to the right object
  $self->builder->create_objects('Export');
  $self->renderer->{'_modal_dialog_'} = $self->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; # Flag indicating that this is modal dialog panel, loaded by AJAX
  $self->page->initialize; # Adds the components to be rendered to the page module  
  $self->configure;
  $self->page->remove_body_element('summary');
  $self->render_page;  
}

1;
