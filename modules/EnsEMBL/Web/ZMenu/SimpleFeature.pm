# $Id$

package EnsEMBL::Web::ZMenu::SimpleFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my ($display_label, $ext_url) = map $hub->param($_), qw(display_label ext_url);
  
  $self->caption($hub->param('logic_name') . ($display_label ? ": $display_label" : ''));
  
  for (qw(score bp)) {
    if (my $param = $hub->param($_)) {
      $self->add_entry({
        type  => $_,
        label => $param
      });
    }
  }
  
  if ($ext_url) {
    $self->add_entry({
      label => $display_label,
      link  => $hub->get_ExtURL($ext_url, $display_label),
      extra => { external => 1 }
    });
  }
}

1;
