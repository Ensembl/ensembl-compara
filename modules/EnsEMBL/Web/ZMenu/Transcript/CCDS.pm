package EnsEMBL::Web::ZMenu::Transcript::CCDS;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  my $object  = $self->object;
  $self->caption($object->gene->stable_id);

  $self->add_entry({
    type  => 'Gene',
    label => $object->gene->stable_id,
    link  => $object->_url({ type => 'Gene', action => 'Summary' }),
    position => 1,
  });

  my $url = $object->get_ExtURL_link( $object->stable_id,'CCDS', $object->stable_id );
  $self->add_entry({
    type  => 'CCDS',
    label => $object->stable_id,
    link  => $url,
    extra => { abs_url => 1 }
  });

  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $object->neat_sr_name($object->seq_region_type,$object->seq_region_name),
      $object->thousandify($object->seq_region_start),
      $object->thousandify($object->seq_region_end)
    ),
    link  => $object->_url({
      type   => 'Location',
      action => 'View',
      r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
    })
  });

  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });

  $self->add_entry({
    type  => 'Base pairs',
    label => $object->thousandify($object->Obj->seq->length)
  });

  if ($object->Obj->translation) {
    $self->add_entry({
      type  => 'Amino acids',
      label => $object->thousandify($object->Obj->translation->length)
    });
  }

  if ($object->analysis) {
    $self->add_entry({
      type  => 'Analysis',
      label => $object->Obj->analysis->display_label
    });
    $self->add_entry({
      label_html => $object->analysis->description
    });
  }
}

1;
