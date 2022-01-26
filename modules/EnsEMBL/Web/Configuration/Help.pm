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

package EnsEMBL::Web::Configuration::Help;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub short_caption {
  return 'Help';
}

sub caption {
  return 'Help';
}

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Search';
}

sub modify_page_elements {
  my $self = shift;
  my $page = $self->page;
  
  $page->remove_body_element('tabs');
  $page->remove_body_element('navigation') if $self->hub->action eq 'ListMappings';
}

sub populate_tree {
  my $self       = shift;
  my $search     = $self->create_node('Search', 'Search', [qw(search EnsEMBL::Web::Component::Search::New)]);
  my $topic_menu = $self->create_submenu('Topics', 'Help topics');
  
  $topic_menu->append($self->create_node('Faq',      'Frequently Asked Questions', [qw(faq      EnsEMBL::Web::Component::Help::Faq)]));
  $topic_menu->append($self->create_node('Movie',    'Video Tutorials',            [qw(movie    EnsEMBL::Web::Component::Help::Movie)]));
  $topic_menu->append($self->create_node('Glossary', 'Glossary',                   [qw(glossary EnsEMBL::Web::Component::Help::Glossary)]));

  $self->create_node('Contact', 'Contact HelpDesk', [qw(contact EnsEMBL::Web::Component::Help::Contact)]);

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node('Preview',         '', [qw(preview EnsEMBL::Web::Component::Help::Preview)]);
  $self->create_node('MovieFeedback',   '', [qw(preview EnsEMBL::Web::Component::Help::MovieFeedback)]);
  $self->create_node('FeedbackPreview', '', [qw(preview EnsEMBL::Web::Component::Help::FeedbackPreview)]);
  $self->create_node('Trackhub',        '', [qw(preview EnsEMBL::Web::Component::Help::Trackhub)]);
  
  $self->create_node('EmailSent',       '', [qw(sent      EnsEMBL::Web::Component::Help::EmailSent)]);
  $self->create_node('Results',         '', [qw(results   EnsEMBL::Web::Component::Help::Results)]);
  $self->create_node('ArchiveList',     '', [qw(archive   EnsEMBL::Web::Component::Help::ArchiveList)]);
  $self->create_node('ArchiveRedirect', '', [qw(archive   EnsEMBL::Web::Component::Help::ArchiveRedirect)]);
  $self->create_node('Permalink',       '', [qw(permalink EnsEMBL::Web::Component::Help::Permalink)]);
  $self->create_node('View',            '', [qw(view      EnsEMBL::Web::Component::Help::View)],);

  ## And command nodes
  $self->create_node('DoSearch',   '', [], { command => 'EnsEMBL::Web::Command::Help::DoSearch'   });
  $self->create_node('Feedback',   '', [], { command => 'EnsEMBL::Web::Command::Help::Feedback'   });
  $self->create_node('SendEmail',  '', [], { command => 'EnsEMBL::Web::Command::Help::SendEmail'  });
  $self->create_node('MovieEmail', '', [], { command => 'EnsEMBL::Web::Command::Help::MovieEmail' });

  $self->create_node('ListMappings', 'Vega', [qw(ListMappings EnsEMBL::Web::Component::Help::ListMappings)], { class => 'modal_link', no_menu_entry => 1 });  
}

1;
