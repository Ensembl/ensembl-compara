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

package EnsEMBL::Web::Document::HTML::Export;

## Show appropriate information about data access, based on available services

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;

  my @services;

  if ($sd->ENSEMBL_MART_ENABLED) {
    push @services, qq(<a href="/biomart/martview">BioMart</a>);
  }
  if ($sd->HAS_API_DOCS) {
    push @services, qq(the <a href="/info/docs/api/index.html">Perl APIs</a>);
  }
  my $rest = $sd->ENSEMBL_REST_URL;
  if ($rest && !$sd->ENSEMBL_REST_INTERNAL_ONLY) {
    push @services, qq(the <a href="$rest">REST API</a>);
  }
  if ($sd->HAS_API_DOCS) {
    push @services, qq(the <a href="info/data/mysql.html">MySQL server</a>);
  }
  my $ftp = $sd->ENSEMBL_FTP_URL;
  if ($ftp) {
    push @services, qq(an <a href="$ftp">FTP site</a>);
  }

  my $html = qq(
<p>We respectfully request that you do not script against the export pages on the Ensembl website, as this degrades the service for other web visitors.
  );

  if (scalar @services) {
    my $last_item   = pop @services;
    my $other_items = join(', ', @services);

    if ($other_items) {
      $html .= qq(
 We provide various large scale export options, including $other_items and $last_item, depending on the volume and type of export you're carrying out.
      );
    }
    else {
      $html .= qq(
We provide $last_item for large-scale export in a variety of formats.
      );
    }
  }

  $html .= qq(</p>

<h2 id="exportingdatafiles">Exporting data files</h2>

<p><img src="/info/data/export_data.png" alt="Export button" title="Export button" /></p>

<p>You'll find the <strong>Export data</strong> button on the left-hand side of many pages in the Gene, Location and Transcript tabs. It allows you to export data related to the gene, location or transcript, not necessarily related to the page you're looking at.</p>

<p>From these links you can export sequence, features in BED, CSV, TSV, GTF, GFF and GFF3 formats, and <a href="http://www.ebi.ac.uk/ena/submit/sequence-format">EMBL</a> or <a href="https://www.ncbi.nlm.nih.gov/Sitemap/samplerecord.html">GenBank</a> flatfiles.</p>

<h2 id="exportingsequence">Exporting sequence</h2>

<p><img src="/info/data/download_sequence.png" alt="Download sequence" title="Download sequence" /></p>

<p>Sequence pages include a link above the sequence for downloading the sequence. You can either download as FASTA, suitable for using with sequence analysis tools, or as rich text format (RTF), for visual analysis.</p>

<h2 id="exportingimages">Exporting images</h2>

<p><img src="/info/data/export_image.png" alt="Export image" title="Export image" /></p>

p>Many images in Ensembl have an export icon at the top-left within the blue bar. This allows you to download images optimised for different purposes, in terms of size, resolution and colour saturation:</p>

<ul>
<li>PDF file - Standard image as PDF file.</li>

<li>Presentation - Saturated image, better suited to projectors.</li>

<li>Poster - Very high resolution, suitable for posters and other large print uses.</li>

<li>Journal/report - High resolution, suitable for printing at A4/letter size.</li>

<li>Web - Standard image, suitable for web pages, blog posts, etc.</li>

<li>Custom image - Select from a range of formats and sizes.</li>

  </ul>

<p>You are welcome to reproduce these images in your own work.</p>

<h2 id="exportingtables">Exporting tables</h2>

<p><img src="/info/data/export_table.png" alt="Export table" title="Export table" /></p>

<p>The icon at the top right of many Ensembl tables allows you to download them as CSV, which you can open as a spreadsheet.</p>

  );

  unless ($sd->NO_COMPARA) {
    $html .= qq(
h2 id="exportingcomparativegenomicsdata">Exporting comparative genomics data</h2>

<p><img src="/info/data/download_homologues.png" alt="Download homologues" title="Download homologues" /></p>

<p><img src="/info/data/export_gene_tree.png" alt="Export gene tree" title="Export gene tree" /></p>

<p>The gene tree and homologue pages allow you to export the gene trees and alignments between the homologues in various formats.</p>
    );
  }

  return $html;

}

1;
