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

  $self->create_node( 'Search', "Search",
    [qw(
      search    EnsEMBL::Web::Component::Help::Search
    )],
    { 'availability' => 1}
  );
  my $topic_menu = $self->create_submenu( 'Topics', 'Help topics' );
  $topic_menu->append($self->create_node( 'FAQ', "Frequently Asked Questions",
    [qw(
      faq    EnsEMBL::Web::Component::Help::FAQ
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
    [qw(
      contact    EnsEMBL::Web::Component::Help::Contact
    )],
    { 'availability' => 1}
  );

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'EmailSent', '',
    [qw(sent EnsEMBL::Web::Component::Help::EmailSent
        )],
      { 'no_menu_entry' => 1 }
  );

}

1;
