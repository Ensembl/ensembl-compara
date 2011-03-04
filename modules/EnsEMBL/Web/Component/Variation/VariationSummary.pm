# $Id$

package EnsEMBL::Web::Component::Variation::VariationSummary;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $variation    = $object->Obj;
  my $html;
 
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

  my @buttons = (
    {'title' => 'Sequence',             'img' => '/img/variation_seq.gif',      'url' => $seq_url},
    {'title' => 'Gene/Transcript',      'img' => '/img/variation_gt.gif',       'url' => $gt_url},
    {'title' => 'Population genetics',  'img' => '/img/variation_pop.gif',      'url' => $pop_url},
    {'title' => 'Individual genotypes', 'img' => '/img/variation_geno.gif',     'url' => $geno_url},
    {'title' => 'Genomic context',      'img' => '/img/variation_context.gif',  'url' => $context_url},
    {'title' => 'Linked variations',    'img' => '/img/variation_ld.gif',       'url' => $ld_url},
    {'title' => 'Phenotype data',       'img' => '/img/variation_pheno.gif',    'url' => $pheno_url},
    {'title' => 'Phylogenetic context', 'img' => '/img/variation_phylo.gif',    'url' => $phylo_url},
  );

  my $html = qq(
    <div class="centered">
  );
  my $i = 0;
  foreach my $button (@buttons) {
    unless ($i > 0 && $i % 4) {
      $html .= qq(
        </div>
        <div class="centered">
      );
    } 
    my $title = $button->{'title'};
    my $img   = $button->{'img'};
    my $url   = $button->{'url'};
    if ($url) {
      $html .= qq(<a href="$url" title="$title"><img src="$img" class="portal" alt="" /></a>);
    }
    else {
      $title .= ' (NOT AVAILABLE)';
      $html .= qq(<img src="$img" class="portal" alt="" title="$title" />);
    }
    $i++;
  }
  $html .= qq(
    </div>
  );

  return $html;
}

1;
