package EnsEMBL::Web::Configuration::UniSearch;

use strict;
use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Summary';
}


sub global_context { return undef; }
sub ajax_content   { return undef;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return undef;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return undef;  }


sub populate_tree {
  my $self = shift;

  $self->create_node( 'Summary', "New Search",
    [qw(
      search    EnsEMBL::Web::Component::UniSearch::Summary
    )],
    { 'availability' => 1}
  );
  $self->create_node( 'Help', "Help",
    [],
    { 'url' => '/info/website/help/', 'raw' => 1, 'availability' => 1}
  );

}

1;
