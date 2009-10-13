# $Id$

package EnsEMBL::Web::ZMenu::Reference;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $ref    = $object->param('reference');
  
  return unless $ref;
  
  $self->caption('Reference');
  
  $self->add_entry({
    label_html => "Compare to $ref",
    link       => $object->_url({ action => 'Population/Image', reference => $object->param('reference') })
  });
}

1;
