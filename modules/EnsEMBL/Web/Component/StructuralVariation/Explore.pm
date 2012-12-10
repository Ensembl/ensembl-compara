package EnsEMBL::Web::Component::StructuralVariation::Explore;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

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

  my $avail    = $self->object->availability;

  my ($gt_url, $context_url, $pheno_url, $supp_url);
  $context_url = $hub->url({'action' => 'Context'});
  if ($avail->{'has_transcripts'}) {
    $gt_url    = $hub->url({'action' => 'Mappings'});
  }
  if ($avail->{'has_transcripts'}) {
    $pheno_url = $hub->url({'action' => 'Phenotype'});
  }
  if ($avail->{'has_supporting_structural_variation'}) {
    $supp_url  = $hub->url({'action' => 'Evidence'});
  }
  

  my @buttons = (
    {'title' => 'Genes and Regulation',   'img' => 'gene_transcript',        'url' => $gt_url},
    {'title' => 'Supporting evidence',    'img' => 'supporting_evidence',    'url' => $supp_url},
    {'title' => 'Genomic context',        'img' => 'genomic_context',        'url' => $context_url},
    {'title' => 'Phenotype data',         'img' => 'phenotype_data',         'url' => $pheno_url},
  );

  my $html = '<div class="icon-holder">';

  foreach my $button (@buttons) {
    my $title = $button->{'title'};
    my $img   = 'var_'.$button->{'img'};
    my $url   = $button->{'url'};
    if ($url) {
      $html .= qq(<a href="$url"><img src="/i/96/${img}.png" class="portal" alt="$title" title="$title" /></a>);
    }
    else {
      $title .= ' (NOT AVAILABLE)';
      $html  .= qq(<img src="/i/96/${img}_off.png" class="portal" alt="$title" title="$title" />);
    }
  }

  $html .= '</div>';

  return $html;
}


1;
