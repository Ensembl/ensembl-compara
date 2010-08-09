package EnsEMBL::Web::Configuration::Server;

use strict;
use base qw(EnsEMBL::Web::Configuration);

sub populate_tree {
  my $self = shift;
  $self->create_node('Information', 'Server information',
    [qw(information EnsEMBL::Web::Component::Server::Information)],
    { 'availability' => 1 }
  );
  $self->create_node('Colourmap', 'Colour map',
    [qw(colourmap EnsEMBL::Web::Component::Server::ColourMap)],
    { 'availability' => 1 }
  );
}

sub user_context   { return $_[0]->_user_context;   }
sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }
sub configurator   { return $_[0]->_configurator;   }

1;

