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

package EnsEMBL::Web::Document::HTML::DataAccess;

## Show appropriate information about data access, based on available services

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;

  my @cells;

  push @cells, qq(<h2>Small quantities of data</h2>
  <p><a href="/info/data/export.html"><img src="/img/download_sequence.gif" class="float-right"  style="width:200px;height:100px" alt="" title="Find out more" /></a>Many of the pages displaying Ensembl genomic data offer an <a href="export.html">export</a>
option, suitable for small amounts of data, e.g. a single gene sequence.</p>
  <p>Click on the 'Export data' button in the lefthand menu of most pages to export:</p>
  <ul>
    <li>FASTA sequence</li>
    <li>GTF or GFF features</li>
  </ul>
  <p>...and more!</p>
);

  ## REST
  my $rest = $sd->ENSEMBL_REST_URL;
  my $internal_only = $sd->ENSEMBL_REST_INTERNAL_ONLY;
  if ($rest && !$internal_only) {
    push @cells, qq(
  <h2>Fast programmatic access</h2>
  <p><a href="$rest"><img src="/img/download_api.gif" class="float-right" style="width:200px;height:100px" alt="" title="Visit our REST site" /></a>For fast access in any programming language, we recommend using our <a href="$rest">REST server</a>. Various REST endpoints provide access to vast amounts of Ensembl data.</p>
);
  }

  ## File downloads
  my $ftp = $sd->ENSEMBL_FTP_URL;
  if ($ftp) {
    push @cells, qq(
  <h2>Complete datasets and databases</h2>

  <p><a href="$rest"><img src="/img/download_code.gif" class="float-right" style="width:200px;height:100px" alt="" title="Find out more" /></a>Many datasets, e.g. all genes for a species, are available to download in a variety of formats from our <a href="$ftp">FTP site</a>.</p>
  <p>Entire databases are also available via FTP as MySQL dumps.</p>
      );
  }

  ## Show Biomart info
  if ($sd->ENSEMBL_MART_ENABLED) {
    push @cells, qq(
  <h2>Complex cross-database queries</h2>
  <p><a href="/biomart/martview"><img src="/img/download_mart.gif" class="float-right"  style="width:200px;height:100px" alt="" title="Try BioMart" /></a>More complex datasets can be retrieved using the <a href="biomart/">BioMart</a> data-mining tool.</p>
);
  }

  my $html = '<table class="blobs">';
  my $count = 0;

  foreach my $cell (@cells) {
    if ($count % 2 == 0) {
      $html .= '<tr>';
    }
    $html .= qq(<td>$cell</td>);
    if ($count % 2 == 1) {
      $html .= '</tr>';
    }

    $count++;
  }

  $html .= '</table>';

  return $html;
}

1;
