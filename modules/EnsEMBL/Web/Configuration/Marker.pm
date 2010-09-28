# $Id$

package EnsEMBL::Web::Configuration::Marker;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Details';
}

sub caption { 
  my $self = shift;
  my $marker = $self->hub->param('m');
  return "Marker $marker"; 
}

sub availability {
  my $self = shift;
  return $self->default_availability;
}

sub populate_tree {
  my $self  = shift;

  $self->create_node('Details', 'Details',
    [qw(details EnsEMBL::Web::Component::Marker::Details)],
    { 'availability' => 1 }
  );
}

1;
