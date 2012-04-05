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

  my ($seq_url, $gt_url, $pop_url, $geno_url, $context_url, $ld_url, $pheno_url, $phylo_url);
  $seq_url        = $hub->url({'action' => 'Sequence'});
  $context_url    = $hub->url({'action' => 'Context'});
  if ($avail->{'has_transcripts'}) {
    $gt_url   = $hub->url({'action' => 'Mappings'});
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
    if ($avail->{'has_ldpops'}) {
      $ld_url    = $hub->url({'action' => 'HighLD'});
    }
  }
  if ($avail->{'has_ega'}) {
    $pheno_url    = $hub->url({'action' => 'Phenotype'});
  }
  if ($avail->{'has_alignments'}) {
    $phylo_url    = $hub->url({'action' => 'Compara_Alignments'});
  }
  
  my ($p_title, $p_img);
  if($avail->{'not_somatic'}) {
    ($p_title, $p_img) = ('Population genetics', 'population_genetics');
  }
  else {
    ($p_title, $p_img) = ('Sample information', 'sample_information');
  }

  my @buttons = (
    {'title' => 'Genomic context',        'img' => 'genomic_context',        'url' => $context_url},
    {'title' => 'Gene/Transcript',        'img' => 'gene_transcript',        'url' => $gt_url},
    {'title' => $p_title,                 'img' => $p_img,                   'url' => $pop_url},
    {'title' => 'Individual genotypes',   'img' => 'individual_genotypes',   'url' => $geno_url},
    {'title' => 'Linkage disequilibrium', 'img' => 'linkage_disequilibrium', 'url' => $ld_url},
    {'title' => 'Phenotype data',         'img' => 'phenotype_data',         'url' => $pheno_url},
    {'title' => 'Phylogenetic context',   'img' => 'phylogenetic_context',   'url' => $phylo_url},
    {'title' => 'Sequence',               'img' => 'flanking_sequence',      'url' => $seq_url},
  );

  my $html;
  my $break = int(scalar(@buttons)/2);
  my $i = 0;

  foreach my $button (@buttons) {
    if (($i % $break) == 0) {
      $html .= qq(
        <div class="centered">
      );
    } 
    my $title = $button->{'title'};
    my $img   = 'var_'.$button->{'img'};
    my $url   = $button->{'url'};
    if ($url) {
      $img .= '.png';
      $html .=
        '<a href="'.$url.'">'.
          '<img src="/i/96/'.$img.'" class="portal" alt="'.$title.'" title"'.$title.'" />'.
        '</a>';
    }
    else {
      $img   .= '_off.png';
      $title .= ' (NOT AVAILABLE)';
      $html .= '<img src="/i/96/'.$img.'" class="portal" alt="'.$title.'" title="'.$title.'" />';
    }
    $i++;
    if ($i > 0 && ($i % $break) == 0) {
      $html .= qq(
        </div>
      );
    }
  }

  ## Variation documentation links
  $html .= qq(
    <h2>Help with variations</h2>

    <div class="twocol-left">
      <h3>YouTube videos</h3>
      <ul>
        <li><a href="/Help/Movie?id=208">Browsing SNPs and CNVs in Ensembl</a></li>
        <li><a href="/Help/Movie?id=214">Clip: Genome Variation</a></li>
        <li><a href="/Help/Movie?id=284">BioMart: Variation IDs to HGNC Symbols</a></li>
      </ul>

      <h3>Interactive tools</h3>
      <ul>
        <li><a href="/$species/UserData/UploadVariations?db=core" class="modal_link">Variant Effect Predictor</a></li>
      </ul>
    </div>

    <div class="twocol-right">
      <h3>Reference materials</h3>
      <ul>
        <li><a href="http://www.ensembl.org/info/docs/variation/index.html">Ensembl variation data: background and terminology</a></li>
        <!--<li><a href="http://www.ensembl.org/info/website/tutorials/variations_worked_example.pdf">Website Walkthrough - Variations</a></li>-->
        <li><a href="http://www.ensembl.org/info/website/tutorials/Ensembl_variation_quick_reference_card.pdf">Variation Quick Reference card</a></li>
      </ul>

      <h3>Additional resources</h3>
      <ul>
        <li><a href="http://www.ensembl.org/info/docs/api/variation/variation_tutorial.html">Accessing variation data with the Variation API</a></li>
        <li><a href="http://www.ensembl.org/info/website/tutorials/malaria_basic_genetics_exercises_Ensembl.pdf">Genomes and SNPs in Malaria</a></li>
      </ul>
    </div>

  );

  return $html;
}


1;
