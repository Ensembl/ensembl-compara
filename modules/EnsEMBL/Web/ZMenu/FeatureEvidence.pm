# $Id$

package EnsEMBL::Web::ZMenu::FeatureEvidence;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object      = $self->object;
  my $db_adaptor  = $object->database($object->param('fdb'));
  my $feature_set = $db_adaptor->get_FeatureSetAdaptor->fetch_by_name($object->param('fs'));
 
  $self->caption('Evidence');
  
  $self->add_entry({
    type  => 'Feature',
    label => $feature_set->display_label
  });
  
  $self->add_entry({
    type  => 'bp',
    label => $object->param('pos')
  });
}

1;
