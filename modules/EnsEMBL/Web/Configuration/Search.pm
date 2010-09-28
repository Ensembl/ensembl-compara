# $Id$

package EnsEMBL::Web::Configuration::Search;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub query_string   { return ''; }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'New';
}

sub populate_tree {
  my $self = shift;

  $self->create_node('New', 'New Search',
    [qw(new EnsEMBL::Web::Component::Search::New)],
    { availability => 1 }
  );

  $self->create_node('Results', 'Results Summary',
    [qw(results EnsEMBL::Web::Component::Search::Results)],
    { no_menu_entry => 1 }
  );

  $self->create_node('Details', 'Result in Detail',
    [qw(details EnsEMBL::Web::Component::Search::Details)],
    { no_menu_entry => 1 }
  );
}

1;
