# $Id$

package EnsEMBL::Web::ZMenu::SimpleFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my ($logic_name, $display_label, $score, $bp, $ext_url) = map $object->param($_), qw(logic_name display_label score bp ext_url);
  
  $self->caption($logic_name . ($display_label ? ": $display_label" : ''));
  
  $self->add_entry({
    type  => 'score',
    label => $score
  });
  
  $self->add_entry({
    type  => 'bp',
    label => $bp
  });
  
  if ($ext_url) {
    $self->add_entry({
      label => $display_label,
      link  => $object->get_ExtURL($ext_url, $display_label),
      extra => { external => 1 }
    });
  }
}

1;
