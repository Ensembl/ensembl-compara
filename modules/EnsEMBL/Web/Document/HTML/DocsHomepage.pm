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

package EnsEMBL::Web::Document::HTML::DocsHomepage;

## Show appropriate information about documentation, based on available services

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;

  my @cells;
  my $rest = $sd->ENSEMBL_REST_URL;

  ## WEBSITE HELP

  my $web_help = qq(
<h2 class="first"><a href="/info/website/">Using this website</a></h2>
<p>Our website offers lots of ways to view and interact with our genomic
data - find out more!</p>
<ul>
<li><a href="/info/website/upload/">Adding custom tracks</a></li>
);

  if ($sd->HAS_TUTORIALS) {
    $web_help .= qq(
<li><a href="/info/website/tutorials/">Tutorials</a></li>
);
  }

  $web_help .= qq(
<li><a href="/info/website/glossary.html">Glossary</a></li>
<li><a href="/Help/Faq" class="popup">FAQs</a> (Frequently Asked Questions)</li>
</ul>
<p style="text-align:right;padding-right:2em;"><a href="/info/website/">More...</a></p>
);

  push @cells, $web_help;

  ## INFO ON GENEBUILD, COMPARA, ETC

  if ($sd->HAS_ANNOTATION) {
    push @cells, $self->get_annotation_html;
  }

  ## DATA DOWNLOADS, FTP, ETC

  my $data_access = qq(
<h2 class="first"><a href="/info/data/">Data access</a></h2>
<p><img src="/img/e-database.gif" alt="db server" class="float-right" style="width:67px;height:76px;padding-right:8px" />All of our data is open-access and can be downloaded free of charge
(<a href="/info/about/legal/">disclaimer</a>). Ways to access this data include:</p>
<ul>
<li><a href="/info/data/export.html">Export</a> features or sequence directly from web pages</li>
);

  if ($sd->ENSEMBL_PUBLIC_DB) {
    $data_access .= qq(
<li>Extract data from our <a href="/info/data/mysql.html">public database</a> using Perl scripts</li>
    );
  }

  if ($sd->ENSEMBL_MART_ENABLED) {
    $data_access .= qq(
<li>Data-mining using the <a href="/info/data/biomart/">BioMart</a> tool</li>
    );
  }

  $data_access .= qq(
<li><a href="/info/data/ftp/">FTP download</a> of complete datasets</li>
);

  if ($rest && !$sd->ENSEMBL_REST_INTERNAL_ONLY) {
    $data_access .= qq(
<li>Access data from our <a href="$rest">REST server</a> using any Programming language</li>
    );
  }

  $data_access .= qq(
</ul>
<p style="text-align:right;padding-right:2em;"><a href="/info/data/">More...</a></p>
);

  push @cells, $data_access;

  ## PROGRAMMATIC ACCESS
  if ($sd->HAS_API_DOCS) {
    
    my $api_docs = qq(
<h2 class="first"><a href="/info/docs/">API &amp; Software</a></h2>
<p><a href="http://www.perl.com/" title="www.perl.com" target="_blank"><img src="/img/info/powered_by_perl.gif" alt="Powered by Perl" class="float-right" style="width:122px;height:55px" /></a>
Ensembl releases all its software under an Apache-style open source
<a href="/info/about/legal/code_licence.html">licence</a>. Our products include:</p>
<ul>
<li><a href="/info/docs/api/">Perl API</a> for direct data access</li>
);

    if ($rest) {
      $api_docs .= qq( 
<li><a href="$rest">REST</a> server for language-agnostic access</li>
      );
    }

    if ($sd->HAS_VIRTUAL_MACHINE) { 
      $api_docs .= qq(
<li><a href="/info/data/virtual_machine.html">Virtual machine</a> preloaded with API</li>
      );
    }

    if ($sd->ENSEMBL_VEP_ENABLED) {
      $api_docs .= qq( 
<li><a href="/info/docs/tools/vep/index.html">Variant Effect Predictor</a> (VEP) and
other command-line scripts</li>
      );
    }

    $api_docs .= qq(
<li><a href="/info/docs/eHive.html">eHive</a> distributed processing system</li>
<li><a href="/info/docs/webcode/">Web frontend</a> (Apache with mod_perl) for mirroring this website</li>
</ul>
<p style="text-align:right;padding-right:2em;"><a href="/info/docs/">More...</a></p>
);

    push @cells, $api_docs;
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

}

sub get_annotation_html {
  my $self = shift;
  my $sd = $self->hub->species_defs;

  my $annotation = qq(
<h2 class="first"><a href="/info/genome/">Annotation &amp; Prediction</a></h2>
<p><img src="/img/4_species.png" alt="various species" class="float-right" style="width:72px;height:72px;padding-right:4px" />The Ensembl project produces genome databases for vertebrates and other
eukaryotic species, and makes this information freely available online.</p>
<ul>
<li><a href="/info/genome/genebuild/">Ensembl annotation</a></li>
    );

  unless ($sd->NO_VARIATION) {
    $annotation .= qq(
<li><a href="/info/genome/variation/">Variation data</a></li>
    );
  }

  unless ($sd->NO_COMPARA) {
    $annotation .= qq(
<li><a href="/info/genome/compara/">Comparative genomics</a></li>
      );
  }

  unless ($sd->NO_REGULATION) {
    $annotation .= qq(
<li><a href="/info/genome/funcgen/">Regulatory build</a></li>
    );
  }

  $annotation .= qq(
</ul>
<p style="text-align:right;padding-right:2em;"><a href="/info/genome/">More...</a></p>
);
  return $annotation;
}


1;
