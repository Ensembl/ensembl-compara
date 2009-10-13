# $Id$

package EnsEMBL::Web::ZMenu::Marker;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $m      = $object->param('m');
  
  $self->caption($m);
  
  $self->add_entry({
    label => 'Marker info.',
    link  => $object->_url({
      type   => 'Location',
      action => 'Marker',
      m      => $m
    })
  });
}

1;
