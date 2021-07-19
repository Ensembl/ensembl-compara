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

package EnsEMBL::Web::Template::Legacy::Popup;

### Legacy page template, used by standard popup pages such as Help 

use parent qw(EnsEMBL::Web::Template::Legacy);

sub init {
  my $self = shift;

  $self->page->add_body_attr('class', 'pop');

  $self->{'main_class'}     = 'main';
  $self->{'lefthand_menu'}  = 1;
  $self->{'tabs'}           = 1;

  $self->add_head;
  $self->add_body;
}

sub add_body {
  my $self = shift;
  my $page = $self->page;
  
  $page->add_body_elements(qw(
    logo            EnsEMBL::Web::Document::Element::Logo
    tabs            EnsEMBL::Web::Document::Element::ModalTabs
    navigation      EnsEMBL::Web::Document::Element::Navigation
    tool_buttons    EnsEMBL::Web::Document::Element::ModalButtons
    content         EnsEMBL::Web::Document::Element::Content
    body_javascript EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

1;
