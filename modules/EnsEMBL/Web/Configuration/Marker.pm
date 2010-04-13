package EnsEMBL::Web::Configuration::Marker;

use strict;
use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Details';
}

sub global_context { return $_[0]->_global_context }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return undef;  } 

sub caption { 
  my $self = shift;
  my $marker = $self->model->hub->param('m');
  return "Marker $marker"; 
}

sub short_caption { return 'Marker-based displays'; }

sub availability {
  my $self = shift;
  return $self->default_availability;
}

sub populate_tree {
  my $self  = shift;

  $self->create_node( 'Details', "Details",
    [qw(details    EnsEMBL::Web::Component::Marker::Details)],
    { 'availability' => 1}
  );
}

1;
