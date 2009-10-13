# $Id$

package EnsEMBL::Web::ZMenu::Supercontig;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $r      = $object->param('r');
 
  $self->caption($object->param('ctg') . " $r");
  
  $self->add_entry({
    label => 'Jump to Supercontig',
    link  => $object->_url({
      type     => 'Location',
      action   => 'Overview',
      r        => $r,
      cytoview => 'misc_feature_core_superctgs=normal'
    })
  });
}

1;
