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
    {'title' => 'Graphical neighbourhood region', 'img' => 'genomic_context',        'url' => $context_url},
    {'title' => 'Consequences (e.g. missense)',   'img' => 'gene_transcript',        'url' => $gt_url},
    {'title' => 'Sample level variant data used to define the structural variant', 
                                                  'img' => 'supporting_evidence',    'url' => $supp_url},
    {'title' => 'Diseases and traits',            'img' => 'phenotype_data',         'url' => $pheno_url},
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

   ## Structural variation documentation links
  $html .= qq(
    <div class="column-wrapper">
      <div class="column-two column-first">
        <div class="column-left">
          <h2>Using the website</h2>
          <ul>
            <li>Video: <a href="/Help/Movie?id=208">Browsing SNPs and CNVs in Ensembl</a></li>
            <li>Video: <a href="/Help/Movie?id=316">Demo: Structural variation for a region</a></li>
          </ul>
          <h2>Analysing your data</h2>
            <p><a href="/$species/UserData/UploadVariations?db=core"><img src="/i/vep_logo_sm.png" alt="[logo]" style="vertical-align:middle" /></a> Test your own structural variants with the <a href="/$species/UserData/UploadVariations?db=core" class="modal_link">Variant Effect Predictor</a></p>
        </div>
      </div>
      <div class="column-two column-next">
        <div class="column-right">
          <h2>Programmatic access</h2>
          <ul>
            <li>Tutorial: <a href="http://www.ensembl.org/info/docs/api/variation/variation_tutorial.html">Accessing structural variation data with the Variation API</a></li>
          </ul>
          <h2>Reference materials</h2>
          <ul>
            <li><a href="http://www.ensembl.org/info/docs/variation/index.html">Ensembl variation data: background and terminology</a></li>
          </ul>
        </div>
      </div>
    </div>
  );

  return $html;
}


1;
