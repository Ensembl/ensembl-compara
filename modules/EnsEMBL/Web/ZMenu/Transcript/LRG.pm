package EnsEMBL::Web::ZMenu::Transcript::LRG;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $transcript  = $object->Obj;
  my $translation = $transcript->translation;

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
    label => $self->thousandify($transcript->seq->length)
  });

  if ($translation) {
    $self->add_entry({
      type     => 'Protein product',
      label    => $translation->stable_id || $object->stable_id,
      #link     => $self->hub->url({ type => 'Transcript', action => 'ProteinSummary' }), # no link for LRGs yet
      position => 3
    });

    $self->add_entry({
      type  => 'Amino acids',
      label => $self->thousandify($translation->length)
    });
  }

  $self->add_entry({
    label_html => $object->analysis->description
  });
}

1;
