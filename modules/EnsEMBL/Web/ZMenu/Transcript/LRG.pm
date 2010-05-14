package EnsEMBL::Web::ZMenu::Transcript::LRG;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  my $object = $self->object;

  $self->caption('LRG Gene');

  $self->add_entry({
    type  => 'Gene type',
    label => $object->gene_stat_and_biotype
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
      type     => 'Protein product',
      label    => $object->Obj->translation->stable_id || $object->Obj->stable_id,
      link     => $object->_url({ type => 'Transcript', action => 'ProteinSummary' }),
      position => 3
    });

    $self->add_entry({
      type  => 'Amino acids',
      label => $object->thousandify($object->Obj->translation->length)
    });
  }

  $self->add_entry({
    label_html => $object->analysis->description
  });
}

1;
