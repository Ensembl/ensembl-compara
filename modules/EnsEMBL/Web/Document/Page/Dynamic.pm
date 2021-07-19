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

package EnsEMBL::Web::Document::Page::Dynamic;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {}

sub initialize_Text {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Content));
  $self->_init;
}

sub initialize_XML {
  my $self = shift;
  my $doctype_version = shift || 'xhtml';
  
  $self->set_doc_type('XML', $doctype_version);
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Content));
  $self->_init;
}

sub initialize_TextGz { shift->initialize_Text; }
sub initialize_Excel  { shift->initialize_Text; }
sub initialize_JSON   { shift->initialize_Text; }

sub initialize_error {
  my $self = shift;
  
  $self->include_navigation(1);
  
  $self->add_head_elements(qw(
    title           EnsEMBL::Web::Document::Element::Title
    stylesheet      EnsEMBL::Web::Document::Element::Stylesheet
    links           EnsEMBL::Web::Document::Element::Links
    meta            EnsEMBL::Web::Document::Element::Meta
    head_javascript EnsEMBL::Web::Document::Element::HeadJavascript
  ));
  
  $self->add_body_elements(qw(
    logo             EnsEMBL::Web::Document::Element::Logo
    search_box       EnsEMBL::Web::Document::Element::SearchBox
    tools            EnsEMBL::Web::Document::Element::ToolLinks
    tabs             EnsEMBL::Web::Document::Element::Tabs
    navigation       EnsEMBL::Web::Document::Element::Navigation
    tool_buttons     EnsEMBL::Web::Document::Element::ToolButtons
    content          EnsEMBL::Web::Document::Element::Content
    modal            EnsEMBL::Web::Document::Element::Modal
    acknowledgements EnsEMBL::Web::Document::Element::Acknowledgements
    copyright        EnsEMBL::Web::Document::Element::Copyright
    footerlinks      EnsEMBL::Web::Document::Element::FooterLinks
    body_javascript  EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

1;
