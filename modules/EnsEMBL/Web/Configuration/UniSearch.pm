# $Id$

package EnsEMBL::Web::Configuration::UniSearch;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Summary';
}

sub modify_page_elements {
  my $self = shift;
  my $page = $self->page;
  
  $page->remove_body_element('global_context');
  $page->remove_body_element('local_tools');
}

sub populate_tree {
  my $self = shift;

  $self->create_node('Summary', 'New Search',
    [qw(search EnsEMBL::Web::Component::UniSearch::Summary )],
    { availability => 1 }
  );
  
  $self->create_node('Help', 'Help',
    [],
    { url => '/info/website/help/', raw => 1, availability => 1 }
  );
}

1;
