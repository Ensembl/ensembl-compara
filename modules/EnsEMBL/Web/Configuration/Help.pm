package EnsEMBL::Web::Configuration::Help;

use strict;
use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Search';
}

sub global_context { return undef; }
sub ajax_content   { return undef;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return undef;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return undef;  }

sub populate_tree {
  my $self = shift;

  my $T = $self->create_node( 'Search', "Search",
    [qw(
      search    EnsEMBL::Web::Component::Help::Search
    )],
    { 'availability' => 1}
  );
  my $topic_menu = $self->create_submenu( 'Topics', 'Help topics' );
  $topic_menu->append($self->create_node( 'Faq', "Frequently Asked Questions",
    [qw(
      faq    EnsEMBL::Web::Component::Help::Faq
    )],
    { 'availability' => 1}
  ));
  $topic_menu->append($self->create_node( 'Movie', "Video Tutorials",
    [qw(
      movie    EnsEMBL::Web::Component::Help::Movie
    )],
    { 'availability' => 1}
  ));
  $topic_menu->append($self->create_node( 'Glossary', "Glossary",
    [qw(
      glossary    EnsEMBL::Web::Component::Help::Glossary
    )],
    { 'availability' => 1}
  ));

  $self->create_node( 'Contact', "Contact HelpDesk",
    [qw(contact    EnsEMBL::Web::Component::Help::Contact)],
    { 'availability' => 1}
  );

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Preview', '',
    [qw(contact    EnsEMBL::Web::Component::Help::Preview)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'MovieFeedback', '',
    [qw(contact    EnsEMBL::Web::Component::Help::MovieFeedback)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'FeedbackPreview', '',
    [qw(contact    EnsEMBL::Web::Component::Help::FeedbackPreview)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $T->append($self->create_subnode( 'EmailSent', '',
    [qw(sent EnsEMBL::Web::Component::Help::EmailSent)],
      { 'no_menu_entry' => 1 }
  ));
  $T->append($self->create_subnode( 'Results', '',
    [qw(sent EnsEMBL::Web::Component::Help::Results
        )],
      { 'no_menu_entry' => 1 }
  ));
  $T->append($self->create_subnode( 'ArchiveList', '',
    [qw(archive EnsEMBL::Web::Component::Help::ArchiveList
        )],
      { 'no_menu_entry' => 1 }
  ));
  $T->append($self->create_subnode( 'Permalink', '',
    [qw(archive EnsEMBL::Web::Component::Help::Permalink
        )],
      { 'no_menu_entry' => 1 }
  ));
  $T->append($self->create_subnode( 'View', '',
    [qw(archive EnsEMBL::Web::Component::Help::View
        )],
      { 'no_menu_entry' => 1 }
  ));

   ## And command nodes
  $self->create_node( 'DoSearch', '',
    [],
    { 'no_menu_entry' => 1, 'command' => 'EnsEMBL::Web::Command::Help::DoSearch'}
  );
  $self->create_node( 'Feedback', '',
    [],
    { 'no_menu_entry' => 1, 'command' => 'EnsEMBL::Web::Command::Help::Feedback'}
  );
  $self->create_node( 'SendEmail', '',
    [],
    { 'no_menu_entry' => 1, 'command' => 'EnsEMBL::Web::Command::Help::SendEmail'}
  );
  $self->create_node( 'MovieEmail', '',
    [],
    { 'no_menu_entry' => 1, 'command' => 'EnsEMBL::Web::Command::Help::MovieEmail'}
  );


}

1;
