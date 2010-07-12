# $Id$

package EnsEMBL::Web::ZMenu::Supercontig;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $r    = $hub->param('r');
 
  $self->caption($hub->param('ctg') . " $r");
  
  $self->add_entry({
    label => 'Jump to Supercontig',
    link  => $hub->url({
      type     => 'Location',
      action   => 'Overview',
      r        => $r,
      cytoview => 'misc_feature_core_superctgs=normal'
    })
  });
}

1;
