=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::ToolsTable;

### Allows easy removal of items from template

use strict;

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render { 
  my $self    = shift;
  my $hub     = EnsEMBL::Web::Hub->new;
  my $sd      = $hub->species_defs;
  my $sp      = $sd->ENSEMBL_PRIMARY_SPECIES;
  my $img_url = $sd->img_url;

  my $sitename = $sd->ENSEMBL_SITETYPE;
  my $html = '<h2>Processing your data</h2>';

  ## Table for online tools
  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name',  title => 'Name', width => '20%', align => 'left' },
      { key => 'desc',  title => 'Description',   width => '40%', align => 'left' },
      { key => 'tool',  title => 'Online tool',   width => '10%', align => 'center' },
      { key => 'limit', title => 'Upload limit',  width => '10%', align => 'center' },
      { key => 'code',  title => 'Download script', width => '10%', align => 'center' },
      { key => 'docs',  title => 'Documentation', width => '10%', align => 'center' },
    ], [], { cellpadding => 4 }
  );

  my $tools_limit = '50MB';

  ## VEP
  my $new_vep  = $sd->ENSEMBL_VEP_ENABLED;
  my $vep_link = $hub->url({'species' => $sp, $new_vep ? qw(type Tools action VEP) : qw(type UserData action UploadVariations)});
  $table->add_row({
    'name' => sprintf('<a href="%s" class="%snodeco"><b>Variant Effect Predictor</b><br /><img src="%svep_logo_sm.png" alt="[logo]" /></a>', $vep_link,  $new_vep ? '' : 'modal_link ', $img_url),
    'desc' => 'Analyse your own variants and predict the functional consequences of known and unknown variants via our Variant Effect Predictor (VEP) tool.',
    'limit' => $tools_limit.'*',
    'tool' => sprintf('<a href="%s" class="%snodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $vep_link, $new_vep ? '' : 'modal_link ', $img_url),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/archive/release/%s.zip" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
    'docs' => sprintf('<a href="/info/docs/tools/vep/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
  });

  ## BLAST
  if ($sd->ENSEMBL_BLAST_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action Blast)});
    $table->add_row({
      'name' => sprintf('<b><a class="nodeco" href="%s">BLAST/BLAT</a></b>', $link),
      'desc' => 'Search our genomes for your DNA or protein sequence.',
      'tool' => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => $tools_limit,
      'code' => '',
      'docs' => sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/Blast'}}), $img_url)
    });
  }

  ## ASSEMBLY CONVERTER
  if ($sd->ENSEMBL_AC_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action AssemblyConverter)});
    $table->add_row({
      'name' => sprintf('<b><a class="nodeco" href="%s">Assembly converter</a></b>', $link),
      'desc' => "Map (liftover) your data's coordinates to the current assembly.",
      'tool' => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => $tools_limit,
      'code' => '',
      'docs' => '',
    });
  }

  ## ID HISTORY CONVERTER
  $table->add_row({
    'name' => '<b>ID History converter</b>',
    'desc' => 'Convert a set of Ensembl IDs from a previous release into their current equivalents.',
    'tool' => sprintf('<a href="%s" class="modal_link nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $hub->url({'species' => $sd->ENSEMBL_PRIMARY_SPECIES, 'type' => 'UserData', 'action' => 'UploadStableIDs'}), $img_url),
    'limit' => '5MB*',
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/id_history_converter" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
    'docs' => '',
  });

  $html .= $table->render;

  $html .= '* For larger datasets we provide an API script that can be downloaded (you will also need to install our Perl API, below, to run the script).';

  ## Table of other tools

  $html .= qq(<h2 class="top-margin">Accessing $sitename data</h2>);

  $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name', title => 'Name', width => '20%', align => 'left' },
      { key => 'desc', title => 'Description', width => '30%', align => 'left' },
      { key => 'from', title => 'Get it from:', width => '30%', align => 'center' },
      { key => 'docs', title => 'Documentation', width => '10%', align => 'center' },
    ], [], { cellpadding => 4 }
  );

  ## BIOMART
  if ($sd->ENSEMBL_MART_ENABLED) {
    $table->add_row({
      'name' => '<b><a href="/biomart/martview">BioMart</a></b>',
      'desc' => "Use this data-mining tool to export custom datasets from $sitename.",
      'from' => qq(<a href="/biomart/martview">$sitename Biomart</a>),
      'docs' => sprintf('<a href="http://www.biomart.org/biomart/mview/help.html" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
    });
  }

  ## PERL API 
  $table->add_row({
    'name' => '<b>Ensembl Perl API</b>',
    'desc' => 'Programmatic access to all Ensembl data using simple Perl scripts',
    'from' => qq(<a href="ftp://ftp.ensembl.org/pub/ensembl-api.tar.gz" rel="external">FTP download</a> (current release only) or <a href="https://github.com/Ensembl">GitHub</a>),
    'docs' => sprintf('<a href="/info/docs/api/"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
  });

  ## VIRTUAL MACHINE
  $table->add_row({
    'name' => '<b>Ensembl Virtual Machine</b>',
    'desc' => 'VirtualBox virtual Machine with Ubuntu desktop and pre-configured with the latest Ensembl API plus Variant Effect Predictor (VEP). <b>NB: download is >1 GB</b>',
    'from' => qq(<a href="ftp://ftp.ensembl.org/pub/current_virtual_machine" rel="external">FTP download</a>),
    'docs' => sprintf('<a href="/info/data/virtual_machine.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
  });

  ## REST
  if (my $rest_url = $sd->ENSEMBL_REST_URL) {
    (my $rest_domain = $rest_url) =~ s/http:\/\///;
    $table->add_row({
      "name" => sprintf("<b><a href=%s>$sitename REST server</a></b>", $rest_url),
      'desc' => 'Access Ensembl data using your favourite programming language',
      "from" => sprintf('<a href="%s">%s</a>', $rest_url, $rest_domain),
      'docs' => sprintf('<a href="%s"><img src="%s16/info.png" alt="Documentation" /></a>', $sd->ENSEMBL_REST_DOC_URL || $rest_url, $img_url)
    });
  }
  $html .= $table->render;

  return $html;
}

1;
