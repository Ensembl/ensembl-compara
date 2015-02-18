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

package EnsEMBL::Web::Component::Variation::Explore;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self               = shift;
  my $hub                = $self->hub;
  my $object             = $self->object;
  my $variation          = $object->Obj;
  my $species            = $hub->species;

  my $avail     = $self->object->availability;

  my ($seq_url, $gt_url, $pop_url, $geno_url, $context_url, $ld_url, $pheno_url, $phylo_url, $cit_url);
  my ($gt_count, $geno_count, $pheno_count, $cit_count);
  $seq_url        = $hub->url({'action' => 'Sequence'});
  $context_url    = $hub->url({'action' => 'Context'});
  if ($avail->{'has_transcripts'}) {
    $gt_url   = $hub->url({'action' => 'Mappings'});
    $gt_count = $avail->{'has_transcripts'};
  }
  if ($avail->{'has_populations'}) {
    if ($avail->{'not_somatic'}) {
      $pop_url   = $hub->url({'action' => 'Population'});
    }
    elsif ($avail->{'is_somatic'}) {
      $pop_url  = $hub->url({'action' => 'Populations'});
    }
  }

  if ($avail->{'has_individuals'} && $avail->{'not_somatic'}) {
    $geno_url   = $hub->url({'action' => 'Individual'});
    $geno_count = $avail->{'has_individuals'};
    if ($avail->{'has_ldpops'}) {
      $ld_url    = $hub->url({'action' => 'HighLD'});
    }
  }
  if ($avail->{'has_ega'}) {
    $pheno_url   = $hub->url({'action' => 'Phenotype'});
    $pheno_count = $avail->{'has_ega'}
  }
  if ($avail->{'has_alignments'}) {
    $phylo_url    = $hub->url({'action' => 'Compara_Alignments'});    
  }
  if ($avail->{'has_citation'}) {
    $cit_url   = $hub->url({'action' => 'Citations'});
    $cit_count = $avail->{'has_citation'};
  }
  
  my ($p_title, $p_img);
  if($avail->{'not_somatic'}) {
    ($p_title, $p_img) = ('Allele and genotype frequencies by population', 'population_genetics');
  }
  else {
    ($p_title, $p_img) = ('Samples with this variant', 'sample_information');
  }

  my @buttons = (
    {'title' => 'Graphical neighbourhood region', 'img' => 'genomic_context','url' => $context_url},
    {'title' => 'Consequences (e.g. missense)',   'img' => 'gene_transcript','url' => $gt_url,    'count' => $gt_count},
    {'title' => $p_title,                 'img' => $p_img,                   'url' => $pop_url},
    {'title' => 'Individual genotypes',   'img' => 'individual_genotypes',   'url' => $geno_url,  'count' => $geno_count},
    {'title' => 'LD plots and tables',    'img' => 'linkage_disequilibrium', 'url' => $ld_url},
    {'title' => 'Diseases and traits',    'img' => 'phenotype_data',         'url' => $pheno_url, 'count' => $pheno_count},
    {'title' => 'Citations',              'img' => 'citations',              'url' => $cit_url,   'count' => $cit_count},
    {'title' => 'Sequence conservation via cross-species alignments',   
                                          'img' => 'phylogenetic_context',   'url' => $phylo_url},
    {'title' => 'Upstream and downstream sequence', 'img' => 'flanking_sequence',      'url' => $seq_url},
  );

  my $html = '<div class="icon-holder">';

  foreach my $button (@buttons) {
    my $title = $button->{'title'};
    my $img   = 'var_'.$button->{'img'};
    my $url   = $button->{'url'};
    if ($url) {      
      my $padding = ($button->{'count'} && $button->{'count'} > 99) ? '' : ($button->{'count'} > 9) ? ' 4px' : ' 6px';
      my $b_count = qq{<span class="counts">$button->{'count'}</span>} if ($button->{'count'});
      $html      .= qq(<div class="icon-container"><a href="$url" style="text-decoration:none"><img src="/i/96/${img}.png" class="portal _ht var_icon" alt="$title" title="$title" />$b_count</a></div>);
    }
    else {
      $title .= ' (NOT AVAILABLE)';
      $html  .= qq(<div class="icon-container"><img src="/i/96/${img}_off.png" class="portal _ht" alt="$title" title="$title" /></div>);
    }
  }

  $html .= '<div style="clear:both"></div>';
  $html .= '</div>';

  ## Variation documentation links
  my $new_vep     = $hub->species_defs->ENSEMBL_VEP_ENABLED;
  my $vep_link    = $hub->url({'species' => $species, '__clear' => 1, $new_vep ? qw(type Tools action VEP) : qw(type UserData action UploadVariations)});
  my $link_class  = $new_vep ? '' : ' class="modal_link"';
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
          <p><a href="$vep_link"$link_class><img src="/i/vep_logo_sm.png" alt="[logo]" style="vertical-align:middle" /></a> Test your own variants with the <a href="$vep_link"$link_class>Variant Effect Predictor</a></p>
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
            <li><a href="/info/genome/variation/data_description.html">Ensembl variation data description</a></li>
            <!--<li><a href="/info/website/tutorials/variations_worked_example.pdf">Website Walkthrough - Variations</a></li>-->
            <li><a href="/info/website/tutorials/Ensembl_variation_quick_reference_card.pdf">Variation Quick Reference card</a></li>
          </ul>
        </div>
      </div>
    </div>
  );

  return $html;
}


1;
