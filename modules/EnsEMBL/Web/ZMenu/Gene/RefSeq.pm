package EnsEMBL::Web::ZMenu::Gene::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self = shift;
  my $object = $self->object;
  $self->caption($object->stable_id);

  if ($object->gene) {
    $self->add_entry({
      type  => 'Gene',
      label => $object->stable_id,
      link  => $object->_url({ type => 'Gene', action => 'Summary' }),
      position => 1,
    });

    $self->add_entry({
      type  => 'RefSeq gene',
      label => $object->stable_id,
      link  => $object->get_ExtURL_link($object->gene->stable_id,'REFSEQ_GENEIMP',$object->gene->stable_id ),
      extra => { abs_url => 1 },
    });
  }

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

  my $biotype = ucfirst(lc $object->Obj->biotype);
  $biotype =~ s/_/ /;
  $self->add_entry({
    type  => 'Gene type',
    label => $biotype,
  });

  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });

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
