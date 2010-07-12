# $Id$

package EnsEMBL::Web::ZMenu::VariationTranscript;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $trans_id   = $hub->param('vt') || die 'No transcript stable ID value in params';
  my $exon_id    = $hub->param('e')  || die 'No exon stable ID value in params';
  my $transcript = $hub->database('core')->get_TranscriptAdaptor->fetch_by_stable_id($trans_id);
  my $protein_id = $transcript->translation ? $transcript->translation->stable_id : '';

  $self->caption($hub->species_defs->AUTHORITY . ' Gene');
  
  $self->add_entry({
    label => $transcript->external_name eq '' ? $trans_id : $transcript->external_db . ': ' . $transcript->external_name
  });
  
  if ($hub->type ne 'Transcript') {
    $self->add_entry({
      type       => 'Gene',
      label_html => $object->stable_id,
      link       => $hub->url({ type => 'Gene', action => 'Summary', g => $object->stable_id })
    });
  }
  
  $self->add_entry({
    type       => 'Transcript',
    label_html => $trans_id,
    link       => $hub->url({ type => 'Transcript', action => 'Summary', t => $trans_id })
  });
  
  if ($protein_id) {
    $self->add_entry({
      type       => 'Protein product',
      label_html => $protein_id,
      link       => $hub->url({ type => 'Transcript', action => 'ProteinSummary', t => $trans_id })
    });
    
    $self->add_entry({
      label_html => 'Export Protein',
      link       => $hub->url({ type => 'Transcript', action => 'Export/fasta', t => $trans_id, param => 'peptide', _format => 'Text' }),
      extra      => { external => 1 },
      position   => 8
    });
  }

  $self->add_entry({
    type  => 'Exon',
    label => $exon_id
  });
  
  $self->add_entry({
    label_html => 'Export cDNA',
    link       => $hub->url({ type => 'Transcript', action => 'Export/fasta', t => $trans_id, param => 'cdna', _format => 'Text' }),
    extra      => { external => 1 }
  });
}

1;
