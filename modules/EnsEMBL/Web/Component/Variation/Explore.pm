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

package EnsEMBL::Web::Component::Variation::Explore;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
  my $variation = $object->Obj;
  my $species   = $hub->species;
  my $avail     = $self->object->availability;

  my ($seq_url, $gt_url, $pop_url, $geno_url, $context_url, $ld_url, $pheno_url, $phylo_url, $cit_url, $prot_url);
  my ($gt_count, $pop_count, $geno_count, $pheno_count, $cit_count);

  if ($avail->{'has_locations'} && $avail->{'has_alignments'}) {
    $seq_url      = $hub->url({'action' => 'Sequence'});
    $context_url  = $hub->url({'action' => 'Context'});
  }

  if ($avail->{'has_features'}) {
    $gt_url   = $hub->url({'action' => 'Mappings'});
    $gt_count = $avail->{'has_features'};
  }

  if ($avail->{'has_populations'}) {
    if ($avail->{'not_somatic'}) {
      $pop_url = $hub->url({'action' => 'Population'});
      $pop_count = $avail->{'has_population_freqs'} if ($avail->{'has_population_freqs'} != 0);
    }
    elsif ($avail->{'is_somatic'}) {
      $pop_url = $hub->url({'action' => 'Populations'});
      $pop_count = $avail->{'has_population_freqs'} if ($avail->{'has_population_freqs'} != 0);
    }
  }

  if ($avail->{'has_samples'} && $avail->{'not_somatic'}) {
    $geno_url   = $hub->url({'action' => 'Sample'});
    $geno_count = $avail->{'has_samples'};
    if ($avail->{'has_ldpops'}) {
      $ld_url = $hub->url({'action' => 'HighLD'});
    }
  }

  if ($avail->{'has_ega'} && $avail->{'has_locations'}) {
    $pheno_url   = $hub->url({'action' => 'Phenotype'});
    $pheno_count = $avail->{'has_ega'}
  }

  if ($avail->{'has_alignments'} && $avail->{'has_variation_source_db'}) {
    $phylo_url = $hub->url({'action' => 'Compara_Alignments'});
  }

  if ($avail->{'has_citation'}) {
    $cit_url   = $hub->url({'action' => 'Citations'});
    $cit_count = $avail->{'has_citation'};
  }

  if ($avail->{'is_coding'} && $avail->{'has_pdbe'}) {
    $prot_url = $hub->url({'action' => 'PDB'});
  }

  my ($p_title, $p_img) = $avail->{'not_somatic'} ? ('Allele and genotype frequencies by population', '96/var_population_genetics.png') : ('Samples with this variant', '96/var_sample_information.png');

  my @buttons = (
    {'title' => 'Graphical neighbourhood region',                     'img' => '96/var_genomic_context.png',        'url' => $context_url                           },
    {'title' => 'Consequences (e.g. missense)',                       'img' => '96/var_gene_transcript.png',        'url' => $gt_url,       'count' => $gt_count    },
    {'title' => 'Upstream and downstream sequence',                   'img' => '96/var_flanking_sequence.png',      'url' => $seq_url                               },
    {'title' => $p_title,                                             'img' => $p_img,                              'url' => $pop_url,      'count' => $pop_count   },
    {'title' => 'Diseases and traits',                                'img' => '96/var_phenotype_data.png',         'url' => $pheno_url,    'count' => $pheno_count },
    {'title' => 'Sample genotypes',                                   'img' => '96/var_sample_genotypes.png',       'url' => $geno_url,     'count' => $geno_count  },
    {'title' => 'LD plots and tables',                                'img' => '96/var_linkage_disequilibrium.png', 'url' => $ld_url                                },
    {'title' => 'Sequence conservation via cross-species alignments', 'img' => '96/var_phylogenetic_context.png',   'url' => $phylo_url                             },
    {'title' => 'Citations',                                          'img' => '96/var_citations.png',              'url' => $cit_url,      'count' => $cit_count   },
    {'title' => '3D Protein model',                                   'img' => '96/var_3d_protein.png',             'url' => $prot_url                              }
  );

  my $html = $self->button_portal(\@buttons);

  ## Variation documentation links
  my $vep_icon = $self->vep_icon;
  $html .= qq(
    <div class="column-wrapper">
      <div class="column-two column-first">
        <div class="column-left">
          <h2>Using the website</h2>
          <ul>
            <li>Video: <a href="/Help/Movie?id=208">Browsing SNPs and CNVs in Ensembl</a></li>
            <li>Video: <a href="/Help/Movie?id=214">Clip: Genome Variation</a></li>
            <li>Video: <a href="/Help/Movie?id=284">BioMart: Variation IDs to HGNC Symbols</a></li>
            <li>Exercise: <a href="/info/website/tutorials/malaria_basic_genetics_exercises_Ensembl.pdf">Genomes and SNPs in Malaria</a></li>
          </ul>
          <h2>Analysing your data</h2>
          <div>$vep_icon</div>
        </div>
      </div>
      <div class="column-two column-next">
        <div class="column-right">
          <h2>Programmatic access</h2>
          <ul>
            <li>Tutorial: <a href="/info/docs/api/variation/variation_tutorial.html">Accessing variation data with the Variation API</a></li>
          </ul>
          <h2>Reference materials</h2>
          <ul>
            <li><a href="/info/genome/variation/index.html">Ensembl variation documentation portal</a></li>
            <li><a href="/info/website/tutorials/Ensembl_variation_quick_reference_card.pdf">Variation Quick Reference card</a></li>
          </ul>
        </div>
      </div>
    </div>
  );

  return $html;
}


1;
