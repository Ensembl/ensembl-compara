# $Id$

package EnsEMBL::Web::ZMenu::Gene;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my @xref   = $object->display_xref;
  
  $self->caption($xref[0] ? "$xref[3]: $xref[0]" : 'Novel transcript');
  
  $self->add_entry({
    type  => 'Gene',
    label => $object->stable_id,
    link  => $object->_url({ type => 'Gene' })
  });
  
  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $object->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $object->thousandify($object->seq_region_start),
      $object->thousandify($object->seq_region_end)
    ),
    link  => $object->_url({
      type   => 'Location',
      action => 'View',
      l      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
    })
  });
  
  $self->add_entry({
    type  => 'Gene type',
    label => $object->gene_type
  });
  
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  
  if ($object->analysis) {
    $self->add_entry({
      type  => 'Analysis',
      label => $object->analysis->display_label
    });
    
    $self->add_entry({
      label_html => $object->analysis->description
    });
  }
}

1;
