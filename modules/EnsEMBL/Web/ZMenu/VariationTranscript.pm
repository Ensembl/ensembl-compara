=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ZMenu::VariationTranscript;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
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
      type  => 'Gene',
      label => $object->stable_id,
      link  => $hub->url({ type => 'Gene', action => 'Summary', g => $object->stable_id })
    });
  }
  
  $self->add_entry({
    type  => 'Transcript',
    label => $trans_id,
    link  => $hub->url({ type => 'Transcript', action => 'Summary', t => $trans_id })
  });
  
  if ($protein_id) {
    $self->add_entry({
      type  => 'Protein',
      label => $protein_id,
      link  => $hub->url({ type => 'Transcript', action => 'ProteinSummary', t => $trans_id })
    });
    
    $self->add_entry({
      label       => 'Export Protein',
      link        => $hub->url('DataExport', { type => 'Protein', action => '', component => 'ProteinSeq', data_type => 'Transcript', t => $trans_id }),
      link_class  => 'modal_link',
      position    => 8
    });
  }

  $self->add_entry({
    type  => 'Exon',
    label => $exon_id
  });
  
  $self->add_entry({
    label       => 'Export cDNA',
    link        => $hub->url('DataExport', { type => 'Transcript', action => '', component => 'TranscriptSeq', data_type => 'Transcript', t => $trans_id }),
    link_class  => 'modal_link'
  });
}

1;
