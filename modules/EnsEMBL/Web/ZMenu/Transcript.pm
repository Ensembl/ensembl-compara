=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Transcript;

use strict;

use Bio::EnsEMBL::SubSlicedFeature;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $stable_id   = $object->stable_id;
  my $transcript  = $object->Obj;
  my $translation = $transcript->translation;
  my @xref        = $object->display_xref;
  my @click       = $self->click_location;
  
  $translation = undef if $transcript->isa('Bio::EnsEMBL::PredictionTranscript'); 

  $self->caption($xref[0] ? "$xref[3]: $xref[0]" : !$object->gene ? $stable_id : 'Novel transcript');
  
  if (scalar @click) {
    ## Has user clicked on an exon (or exons)?
    my @exons;
    
    foreach (@{$transcript->get_all_Exons}) {
      my ($s, $e) = ($_->start, $_->end);
      
      if (
        ($s <= $click[1] && $e >= $click[2]) || # click is completely inside exon
        ($s >= $click[1] && $e <= $click[2])    # click completely contains exon
      ) {
        push @exons, $_->stable_id;
      }
    }
    
    ## Only link to an individual exon if the user has clicked squarely 
    ## on an exon (i.e. ignore when zoomed out or exons are tiny)
    if (scalar @exons == 1) {
      $self->add_entry({
        type  => 'Exon',
        label => $exons[0],
        link  => $hub->url({ type => 'Transcript', action => 'Exons', exon => $exons[0] })
      });
    }
  }
  
  $self->add_entry({
    type  => 'Transcript',
    label => $stable_id, 
    link  => $hub->url({ type => 'Transcript', action => 'Summary' })
  });
  
  # Protein coding transcripts only
  if ($translation) {
    $self->add_entry({
      type  => 'Protein',
      label => $translation->stable_id || $stable_id,
      link  => $self->hub->url({ type => 'Transcript', action => 'ProteinSummary' }),
    });
  }
  
  # Only if there is a gene (not Prediction transcripts)
  if ($object->gene) {
    $self->add_entry({
      type  => 'Gene',
      label => $object->gene->stable_id,
      link  => $hub->url({ type => 'Gene', action => 'Summary' })
    });
    
    $self->add_entry({
      type  => 'Location',
      label => sprintf(
        '%s: %s-%s',
        $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
        $self->thousandify($object->seq_region_start),
        $self->thousandify($object->seq_region_end)
      ),
      link  => $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
      })
    });
  }

  $self->add_entry({
    type  => ' ',
    label => 'cDNA Sequence',
    link  => $hub->url({ type => 'Transcript', action => 'Sequence_cDNA' })
  });

  $self->add_entry({
    type  => ' ',
    label => 'Protein Variations',
    link  => $self->hub->url({ type => 'Transcript', action => 'ProtVariations' }),
  }) if($translation);

  
  if ($object->transcript_type) {
    $self->add_entry({
      type  => 'Transcript type',
      label => $object->transcript_type
    });
  }
  
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  
  $self->add_entry({
    type  => 'Base pairs',
    label => $self->thousandify($transcript->seq->length)
  });
  
  # Protein coding transcripts only
  if ($translation) {
    $self->add_entry({
      type  => 'Amino acids',
      label => $self->thousandify($translation->length)
    });
  }

  if ($object->analysis) {
    my $label = $transcript->analysis->display_label . ' Transcript';
    $self->add_entry({
      type  => 'Source',
      label => $label
    });
  }
}

1;
