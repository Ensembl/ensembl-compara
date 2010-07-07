# $Id$

package EnsEMBL::Web::ZMenu::SimpleFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my ($display_label, $ext_url) = map $object->param($_), qw(display_label ext_url);
  
  $self->caption($object->param('logic_name') . ($display_label ? ": $display_label" : ''));
  
  for (qw(score bp)) {
    if (my $param = $object->param($_)) {
      $self->add_entry({
        type  => $_,
        label => $param
      });
    }
  }
  
  if ($ext_url) {
    $self->add_entry({
      label => $display_label,
      link  => $object->get_ExtURL($ext_url, $display_label),
      extra => { external => 1 }
    });
  }
}

1;
