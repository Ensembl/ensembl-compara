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

package EnsEMBL::Web::Template::Legacy::Static;

### Legacy page template, used by most static pages such as site documentation
### Note that since static pages have no Configuration module, we can only use
### a single template at present and tweak it based on URL

use parent qw(EnsEMBL::Web::Template::Legacy);

sub init {
  my $self = shift;

  my $here = $ENV{'REQUEST_URI'};

  if ($here =~ /Doxygen\/index.html/ || ($here =~ /^\/info/ && $here !~ /Doxygen/)) {
    ## Standard documentation page
    $self->{'main_class'}     = 'main';
    $self->{'lefthand_menu'}  = 1;
    $self->{'tabs'}           = 1;
  }
  else {
    ## Full-width page with no navigation 
    $self->{'main_class'}     = 'widemain';
    $self->{'lefthand_menu'}  = 0;
    $self->{'tabs'}           = 0;
  }

  ## Elixir banner on home page
  $self->{'show_banner'} = 1 if ($here eq '/index.html');

  $self->add_head;
  $self->add_body;
}

sub add_head {
  my $self = shift;
  my $page = $self->page;
  
  $page->add_head_elements(qw(
    title      EnsEMBL::Web::Document::Element::Title
    stylesheet EnsEMBL::Web::Document::Element::Stylesheet
    javascript EnsEMBL::Web::Document::Element::Javascript
    links      EnsEMBL::Web::Document::Element::Links
    meta       EnsEMBL::Web::Document::Element::Meta
    prefetch   EnsEMBL::Web::Document::Element::Prefetch
  ));
}

sub add_body {
  my $self = shift;
  my $page = $self->page;
  
  $page->add_body_elements(qw(
    logo             EnsEMBL::Web::Document::Element::Logo
    account          EnsEMBL::Web::Document::Element::AccountLinks
    search_box       EnsEMBL::Web::Document::Element::SearchBox
    tools            EnsEMBL::Web::Document::Element::ToolLinks
  ));

  if ($self->{'tabs'}) {
    $page->add_body_elements(qw(
      tabs             EnsEMBL::Web::Document::Element::StaticTabs
    ));
  }

  if ($self->{'lefthand_menu'}) {
    $page->add_body_elements(qw(
      navigation       EnsEMBL::Web::Document::Element::StaticNav
    ));
  }

  $page->add_body_elements(qw(
    breadcrumbs      EnsEMBL::Web::Document::Element::BreadCrumbs
    content          EnsEMBL::Web::Document::Element::Content
    modal            EnsEMBL::Web::Document::Element::Modal
    copyright        EnsEMBL::Web::Document::Element::Copyright
    footerlinks      EnsEMBL::Web::Document::Element::FooterLinks
    fatfooter        EnsEMBL::Web::Document::Element::FatFooter
  ));

  if ($self->{'show_banner'}) {
    $page->add_body_elements(qw(
      bottom_banner  EnsEMBL::Web::Document::Element::BottomBanner
    ));
  }

  $page->add_body_elements(qw(
    tmp_message      EnsEMBL::Web::Document::Element::TmpMessage
    body_javascript  EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

1;
