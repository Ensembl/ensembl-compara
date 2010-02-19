package EnsEMBL::Web::ZMenu::Transcript::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  my $object = $self->object;
  $self->caption($object->gene->stable_id);

  if ($object->gene) {
    $self->add_entry({
      type  => 'Gene',
      label => $object->gene->stable_id,
      link  => $object->_url({ type => 'Gene', action => 'Summary' }),
      position => 1,
    });

    $self->add_entry({
      type  => 'RefSeq gene',
      label => $object->gene->stable_id,
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

  my $biotype = ucfirst(lc $object->gene->biotype);
  $biotype =~ s/_/ /;
  $self->add_entry({
    type  => 'Gene type',
    label => $biotype,
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
      type  => 'RefSeq protein',
      label => $object->Obj->translation->stable_id || $object->Obj->stable_id,
      link  => $object->get_ExtURL_link($object->stable_id,'REFSEQ_PEPTIDE',$object->stable_id ),
      position => 3,
      extra => { abs_url => 1 },
    });
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
