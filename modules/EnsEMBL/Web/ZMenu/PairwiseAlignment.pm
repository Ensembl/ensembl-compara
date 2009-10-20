# $Id$

package EnsEMBL::Web::ZMenu::PairwiseAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object      = $self->object;
  my $r1          = $object->param('r1');
  my $sp1         = $object->param('s1');
  my $orient      = $object->param('orient');
  my $disp_method = $object->param('method');
  
  my $url = $object->_url({
    type    => 'Location',
    action  => 'View',
    species => $sp1,
    r       => $r1
  });
  
  $self->add_entry({
    type => $r1
  });
  
  $self->add_entry({
    type  => 'Orientation',
    label => $orient
  });
  
  $self->add_entry({
    label => "Jump to $sp1",
    link  => $url
  });

  if ($disp_method) {
    $url = $object->_url({
      type   => 'Location',
      action => 'ComparaGenomicAlignment',
      s1     => $sp1,
      r1     => $r1,
      method => $disp_method
    });
     
    $self->add_entry({
      label => 'View alignment',
      link  => $url
    });

    $url = $object->_url({
      type   => 'Location',
      action => 'View',
      r      => $object->param('r')
    });
    
    $self->add_entry({
      label => 'Center on this location',
      link  => $url
    });
  }
  
  $sp1 =~ s/_/ /g;
  $disp_method =~ s/BLASTZ_NET/BLASTz net/g;
  $disp_method =~ s/TRANSLATED_BLAT_NET/Trans. BLAT net/g;
  
  $self->caption("$sp1 - $disp_method");
}

1;
