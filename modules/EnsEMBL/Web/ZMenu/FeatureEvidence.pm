# $Id$

package EnsEMBL::Web::ZMenu::FeatureEvidence;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $db_adaptor  = $hub->database($hub->param('fdb'));
  my $feature_set = $db_adaptor->get_FeatureSetAdaptor->fetch_by_name($hub->param('fs'));
 
  $self->caption('Evidence');
  
  $self->add_entry({
    type  => 'Feature',
    label => $feature_set->display_label
  });
  
  $self->add_entry({
    type  => 'bp',
    label => $hub->param('pos')
  });

  if ($hub->param('ps') !~ /undetermined/) {
    $self->add_entry({
      type  => 'Peak summit',
      label => $hub->param('ps')
    });
  }
}

1;
