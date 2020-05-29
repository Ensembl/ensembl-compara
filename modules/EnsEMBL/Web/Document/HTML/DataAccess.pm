=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

  my $html = '';

  ## REST
  my $rest = $sd->ENSEMBL_REST_URL;
  if ($rest) {
    $html .= qq(<h2>Fast programmatic access</h2>
<p>For fast access in any programming language, we recommend using our <a href="$rest">REST server</a>. Various REST endpoints provide access to vast amounts of Ensembl data.</p>
);
  }

  ## Show Biomart info
  if ($sd->ENSEMBL_MART_ENABLED) {
    $html .= qq(<h2>Complex cross-database queries</h2>
<p>More complex datasets can be retrieved using the <a href="biomart/">BioMart</a> data-mining tool.</p>);
  }

  ## File downloads
  my $ftp = $sd->ENSEMBL_FTP_URL;
  if ($ftp) {
    $html .= qq(
<h2>Complete datasets and databases</h2>

<p>Many datasets, e.g. all genes for a species, are available to download in a variety of formats from our <a href="$ftp">FTP site</a>.</p>
<p>Entire databases are also available via FTP as MySQL dumps.</p>
      );
  }

}

1;
