# $Id$

package EnsEMBL::Web::ZMenu::Marker;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $m    = $hub->param('m');
  
  $self->caption($m);
  
  $self->add_entry({
    label => 'Marker info.',
    link  => $hub->url({
      type   => 'Marker',
      action => 'Details',
      m      => $m
    })
  });
}

1;
