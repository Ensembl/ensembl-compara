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

package EnsEMBL::Web::Document::HTML::ToolBox;

### This module shows links to tools, if they are enabled

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;
  my $html;

  if ($sd->ENSEMBL_BLAST_ENABLED || $sd->ENSEMBL_MART_ENABLED || $sd->ENSEMBL_VEP_ENABLED) {

    $html .= qq(
      <div class="plain-box no-top-margin">
        <div style="float:left;width:15%">
          <div class="plain-box unbordered">
            <h2>Tools</h2>
            <p><a href="/info/docs/tools/index.html">All tools</a></p>
          </div>
        </div>);

    if ($sd->ENSEMBL_MART_ENABLED) {
      $html .= qq(
        <div style="float:left;width:28%">
          <div class="plain-box unbordered">
            <h2><a href="/biomart/martview" class="nodeco">BioMart&nbsp&nbsp;&gt;</a></h2>
            <p>Export custom datasets from Ensembl with this data-mining tool</p>
          </div>
        </div>);
    }
    if ($sd->ENSEMBL_BLAST_ENABLED) {
      my %tools = @{$sd->ENSEMBL_TOOLS_LIST||[]};
      my $label = $tools{'Blast'} || 'BLAST';;
      $html .= qq(
        <div style="float:left;width:28%">
          <div class="plain-box unbordered">
            <h2><a href="/Multi/Tools/Blast?db=core" class="nodeco">$label&nbsp&nbsp;&gt;</a></h2>
            <p>Search our genomes for your DNA or protein sequence</p>
          </div>
        </div>);
    }
    if ($sd->ENSEMBL_VEP_ENABLED) {
      $html .= qq(
        <div style="float:left;width:28%">
          <div class="plain-box unbordered">
            <h2><a href="/info/docs/tools/vep/" class="nodeco">Variant Effect Predictor&nbsp;&nbsp;&gt;</a></h2>
            <p>Analyse your own variants and predict the functional consequences of
            known and unknown variants</p>
          </div>
        </div>);
    }
    $html .= '</div>';
  }

  return $html;

}


1;
