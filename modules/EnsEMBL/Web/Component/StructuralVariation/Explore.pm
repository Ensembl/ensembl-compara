=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::StructuralVariation::Explore;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

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

  my ($gt_url, $context_url, $pheno_url, $supp_url);
  my ($gt_count, $supp_count, $pheno_count);
  $context_url = $hub->url({'action' => 'Context'});

  if ($avail->{'has_transcripts'}) {
    $gt_url   = $hub->url({'action' => 'Mappings'});
    $gt_count = $avail->{'has_transcripts'};
  }

  if ($avail->{'has_phenotypes'}) {
    $pheno_url = $hub->url({'action' => 'Phenotype'});
    $pheno_count = $avail->{'has_phenotypes'};
  }

  if ($avail->{'has_supporting_structural_variation'}) {
    $supp_url   = $hub->url({'action' => 'Evidence'});
    $supp_count = $avail->{'has_supporting_structural_variation'};
  }

  my $supp_title = 'Sample level variant data used to define the structural variant';

  my @buttons = (
    {'title' => 'Graphical neighbourhood region', 'img' => '96/var_genomic_context.png',        'url' => $context_url                         },
    {'title' => 'Consequences (e.g. missense)',   'img' => '96/var_gene_transcript.png',        'url' => $gt_url   ,  'count' => $gt_count    },
    {'title' => $supp_title,                      'img' => '96/var_supporting_evidence.png',    'url' => $supp_url ,  'count' => $supp_count  },
    {'title' => 'Diseases and traits',            'img' => '96/var_phenotype_data.png',         'url' => $pheno_url , 'count' => $pheno_count },
  );

  my $html = $self->button_portal(\@buttons);

  ## Structural variation documentation links
  my $vep_icon = $self->vep_icon;
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
          <div>$vep_icon</div>
        </div>
      </div>
      <div class="column-two column-next">
        <div class="column-right">
          <h2>Programmatic access</h2>
          <ul>
            <li>Tutorial: <a href="/info/docs/api/variation/variation_tutorial.html#structural">Accessing structural variation data with the Variation API</a></li>
          </ul>
          <h2>Reference materials</h2>
          <ul>
            <li><a href="/info/genome/variation/index.html">Ensembl variation documentation portal</a></li>
          </ul>
        </div>
      </div>
    </div>
  );

  return $html;
}


1;
