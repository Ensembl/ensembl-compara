package EnsEMBL::Web::Configuration::Search;

use strict;
use base qw( EnsEMBL::Web::Configuration );
use ExaLead::Renderer::HTML;

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub context_panel  { return undef;  }
sub content_panel  { return $_[0]->_content_panel; }

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'New';
}


sub populate_tree {
  my $self = shift;

  $self->create_node( 'New', "New Search",
    [qw(new    EnsEMBL::Web::Component::Search::New)],
    { 'availability' => 1}
  );

  $self->create_node( 'Results', "Results Summary",
    [qw(results    EnsEMBL::Web::Component::Search::Results)],
    { 'no_menu_entry' => 1}
  );

  $self->create_node( 'Details', "Result in Detail",
    [qw(details    EnsEMBL::Web::Component::Search::Details)],
    { 'no_menu_entry' => 1}
  );

}

1;
