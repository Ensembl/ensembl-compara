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

package EnsEMBL::Web::ZMenu::Transcript;

use strict;

use Bio::EnsEMBL::SubSlicedFeature;
use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $stable_id   = $object->stable_id;
  my $transcript  = $object->Obj;
  my $translation = $transcript->translation;
  my $gene        = $object->gene;
  my $gene_desc   = $gene ? $object->gene_description =~ s/No description//r =~ s/\[.+\]\s*$//r : '';
  my @xref        = $object->display_xref;
  my @click       = $self->click_location;
  my @all_exons   = @{$transcript->get_all_Exons};
  my @all_introns = @{$transcript->get_all_Introns};
  my (@exons, @introns); 
  
  $translation = undef if $transcript->isa('Bio::EnsEMBL::PredictionTranscript');

  # Genscan doesn't have a gene
  # so check if gene is defined else use transcript info for caption
  if (defined $gene) {
    $self->caption($gene->display_xref ? $gene->display_xref->db_display_name.": ".$gene->display_xref->display_id : !$gene ? $stable_id : 'Transcript');
  } else {
    $self->caption($transcript->display_xref ? $transcript->display_xref->db_display_name.": ".$transcript->display_xref->display_id : $stable_id);
  }
    
  if (scalar @click) {
    ## Has user clicked on an exon (or exons)? If yes find out the exon rank to display in zmenu
    foreach (@all_exons) {
      my ($s, $e) = ($_->start, $_->end);
   
      if (
        ($s <= $click[1] && $e >= $click[2]) ||   # click is completely inside exon
        ($s >= $click[1] && $e <= $click[2]) ||   # click completely contains exon
        ($click[1] <= $s && $click[2] >= $s) ||   # start of exon is part of click
        ($click[1] <= $e && $click[2] >= $e)      # click is end of exon
      ) {      
        push @exons, $_->rank($transcript);
      }
    }
    ## Has user clicked on an intron (or introns)? If yes find out the intron rank to display in zmenu
    foreach (@all_introns) {
      my ($st, $en) = ($_->start, $_->end);
      
      if (
        ($st <= $click[1] && $en >= $click[2]) || # click is completely on an intron
        ($st >= $click[1] && $en <= $click[2]) || # click completely contains intron
        ($click[1] <= $st && $click[2] >= $st) || # start of intron is part of click
        ($click[1] <= $en && $click[2] >= $en)    # click is end of intron
      ) {      
        push @introns, $_->rank($transcript);   #TO uncomment once core added the rank call for intron      
      }
    }    
  }
  
  # Only if there is a gene (not Prediction transcripts)
  if ($gene) {  
    if($gene_desc) {
      $self->add_entry({
        type  => 'Gene',
        label => $gene_desc
      });
      
      $self->add_entry({
        type  => ' ',
        label => $gene->stable_id,
        link  => $hub->url({ type => 'Gene', action => 'Summary' })
      }); 
    } else {
      $self->add_entry({
        type  => 'Gene',
        label => $gene->stable_id,
        link  => $hub->url({ type => 'Gene', action => 'Summary' })
      });     
    }
    
    $self->add_entry({
      type  => 'Location',
      label => sprintf(
        '%s: %s-%s',
        $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
        $self->thousandify($object->seq_region_start),
        $self->thousandify($object->seq_region_end)
      ),
      link_class => '_location_change _location_mark',
      link  => $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
      })
    });
  }

  @introns = () if(scalar @exons && scalar @introns); #when click is on both exon and intron, exon takes precedence
  $self->add_entry({
    type  => 'Exon',
    label => $exons[0]." of ". scalar(@all_exons)
  }) if(scalar @exons);
  
  $self->add_entry({
    type  => 'Intron',
    label => $introns[0]." of ". scalar(@all_introns)
  }) if(scalar @introns);  
  
  if($xref[0] && $xref[0] ne $stable_id) { # if there is transcript symbol then show it as the first label and stable id as second label, if not then stable id as first label
    $self->add_entry({
      type  => 'Transcript',
      label => $xref[0]
    });

    $self->add_entry({
      type  => ' ',
      label => $transcript->version ? $stable_id . "." . $transcript->version : $stable_id,
      link  => $hub->url({ type => 'Transcript', action => 'Summary' })
    });
 } else {
    $self->add_entry({
      type  => 'Transcript',
      label => $transcript->version ? $stable_id . "." . $transcript->version : $stable_id,
      link  => $hub->url({ type => 'Transcript', action => 'Summary' })
    });
 }

  $self->add_entry({
    type  => ' ',
    label => "Exons",
    link  => $hub->url({ type => 'Transcript', action => 'Exons' })
  });
 
  $self->add_entry({
    type  => ' ',
    label => 'cDNA Sequence',
    link  => $hub->url({ type => 'Transcript', action => 'Sequence_cDNA' })
  });  
  
  # Protein coding transcripts only
  if ($translation) {
    $self->add_entry({
      type  => 'Protein',
      label => $translation->stable_id || $stable_id,
      link  => $self->hub->url({ type => 'Transcript', action => 'ProteinSummary' }),
    });
  }

  if ($translation && $object->availability->{'has_variations'}) {
    $self->add_entry({
      type  => ' ',
      label => 'Protein Variations',
      link  => $self->hub->url({ type => 'Transcript', action => 'ProtVariations' }),
    });
  }  

  $self->add_entry({
      type  => 'Gene type',
      label => $object->gene_stat_and_biotype
  }) if ($gene);
 
  
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
    my $analysis = $transcript->analysis;
    $self->add_entry({
      type        => 'Source',
      label_html  => helptip($analysis->display_label, $analysis->description)
    });
  }
  my $alt_allele_link = $object->get_alt_allele_link('Location');
  $self->add_entry({
                    'type'       => 'Gene alleles',
                    'label_html' => $alt_allele_link,
                  }) 
    if $alt_allele_link;
}

1;
