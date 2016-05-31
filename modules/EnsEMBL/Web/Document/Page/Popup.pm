=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Page::Popup;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {
  my $self = shift;

  return $self->initialize_JSON if $self->renderer->{'_modal_dialog_'};
}

sub initialize_JSON {
  my $self = shift;
  
  $self->add_body_elements(qw(
    tabs         EnsEMBL::Web::Document::Element::ModalTabs
    navigation   EnsEMBL::Web::Document::Element::Navigation
    tool_buttons EnsEMBL::Web::Document::Element::ModalButtons
    content      EnsEMBL::Web::Document::Element::Content
  ));
}

sub panel_type {
  return '<input type="hidden" class="panel_type" value="ModalContent" />' if $_[0]->renderer->{'_modal_dialog_'};
}

1;
