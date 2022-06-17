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

package EnsEMBL::Web::Template::Legacy::Wide;

### Legacy page template, used by dynamic pages with no lefthand navigation
### and also top-level static pages

use parent qw(EnsEMBL::Web::Template::Legacy);

sub init {
  my $self = shift;
  $self->{'main_class'}     = 'widemain';
  $self->{'lefthand_menu'}  = 0;
  $self->{'has_species_bar'}  = $self->hub->species && $self->hub->species !~ /multi|common/i ? 1 : 0;
  $self->{'has_tabs'}         = $self->hub->controller->configuration->has_tabs;
  $self->add_head;
  $self->add_body;
}

sub add_body {
  my $self = shift;
  my $page = $self->page;

  $page->add_body_elements(qw(
    logo             EnsEMBL::Web::Document::Element::Logo
  ));

  if ($self->{'has_species_bar'}) {
    $page->add_body_elements(qw(
      species_bar      EnsEMBL::Web::Document::Element::SpeciesBar
    ));
  }

  $page->add_body_elements(qw(
    account          EnsEMBL::Web::Document::Element::AccountLinks
    search_box       EnsEMBL::Web::Document::Element::SearchBox
    tools            EnsEMBL::Web::Document::Element::ToolLinks
    content          EnsEMBL::Web::Document::Element::Content
    modal            EnsEMBL::Web::Document::Element::Modal
    copyright        EnsEMBL::Web::Document::Element::Copyright
    footerlinks      EnsEMBL::Web::Document::Element::FooterLinks
    fatfooter        EnsEMBL::Web::Document::Element::FatFooter
    tmp_message      EnsEMBL::Web::Document::Element::TmpMessage
    body_javascript  EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}


1;
