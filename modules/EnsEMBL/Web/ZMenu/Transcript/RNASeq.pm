package EnsEMBL::Web::ZMenu::Transcript::RNASeq;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $object = $self->object;
  my $transcript   = $object->Obj;
  my $caption = $object->stable_id;
  
  $self->caption($caption);

  # change label for gene type
  $self->modify_entry_by('type',{
    type  => 'Gene type',
    label => $transcript->biotype,
  });

  # add new entries for attributes
  foreach my $attrib (@{$transcript->get_all_Attributes('AltThreePrime') || []}) {
    $self->add_entry({
      type  => $attrib->{'name'},
      label => $attrib->{'value'},
    });
  }

  if ($object->species eq 'Homo_sapiens') {
    $self->delete_entry_by_value($object->stable_id);
    $self->delete_entry_by_value($object->gene->stable_id);
    my $loc = sprintf(
        '%s: %s-%s',
        $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
        $self->thousandify($object->seq_region_start),
        $self->thousandify($object->seq_region_end)
      );
    $self->delete_entry_by_value($loc);
    $self->delete_entry_by_value($object->gene_stat_and_biotype);
    if (my $translation = $transcript->translation) {
      $self->delete_entry_by_value($self->thousandify($translation->length));
    }
  }
  
  # delete unwanted entry and then re-add - adds it to the bottom of the zmenu
  $self->delete_entry_by_value($object->analysis->description);
  
  $self->add_entry({
    label_html => $object->analysis->description
  });
}

1;
