=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my $img_url = $sd->img_url;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name', title => 'Name', width => '20%', align => 'left' },
      { key => 'desc', title => 'Description', width => '50%', align => 'left' },
      { key => 'tool', title => 'Online tool', width => '10%', align => 'center' },
      { key => 'code', title => 'Download code', width => '10%', align => 'center' },
      { key => 'docs', title => 'Documentation', width => '10%', align => 'center' },
    ], [], { cellpadding => 4 }
  );

  ## VEP
  my $vep_link = $hub->url({'species' => $sd->ENSEMBL_PRIMARY_SPECIES, 'type' => 'Tools', 'action' => 'VEP'});
  $table->add_row({
    'name' => sprintf('<a href="%s" class="nodeco"><b>Variant Effect Predictor</b><br /><img src="%svep_logo_sm.png" alt="[logo]" /></a>', $vep_link, $img_url),
    'desc' => 'Analyse your own variants and predict the functional consequences of known and unknown variants via our Variant Effect Predictor (VEP) tool.',
    'tool' => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $vep_link, $img_url),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/archive/release/%s.zip" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
    'docs' => sprintf('<a href="/info/docs/tools/vep/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
  });

  ## BLAST
  if ($sd->ENSEMBL_BLAST_ENABLED) {
    $table->add_row({
      'name' => '<b><a href="/Multi/blastview">BLAST/BLAT</a></b>',
      'desc' => 'Search our genomes for your DNA or protein sequence.',
      'tool' => sprintf('<a href="/Multi/blastview" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $img_url),
      'code' => '',
      'docs' => sprintf('<a href="%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Multi/blastview'}}), $img_url)
    });
  }

  ## BIOMART
  if ($sd->ENSEMBL_MART_ENABLED) {
    $table->add_row({
      'name' => '<b><a href="/biomart/martview">BioMart</a></b>',
      'desc' => 'Use this data-mining tool to export custom datasets from Ensembl.',
      'tool' => sprintf('<a href="/biomart/martview" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $img_url),
      'code' => sprintf('<a href="http://biomart.org" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download code from biomart.org" /></a>', $img_url),
      'docs' => sprintf('<a href="http://www.biomart.org/biomart/mview/help.html" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
    });
  }

  ## ASSEMBLY CONVERTER
  $table->add_row({
    'name' => '<b>Assembly converter</b>',
    'desc' => "Map (liftover) your data's coordinates to the current assembly.",
    'tool' => sprintf('<a href="%s" class="modal_link nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $hub->url({'species' => $sd->ENSEMBL_PRIMARY_SPECIES, 'type' => 'UserData', 'action' => 'SelectFeatures'}), $img_url),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/assembly_converter" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
    'docs' => '',
  });

  ## ID HISTORY CONVERTER
  $table->add_row({
    'name' => '<b>ID History converter</b>',
    'desc' => 'Convert a set of Ensembl IDs from a previous release into their current equivalents.',
    'tool' => sprintf('<a href="%s" class="modal_link nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $hub->url({'species' => $sd->ENSEMBL_PRIMARY_SPECIES, 'type' => 'UserData', 'action' => 'UploadStableIDs'}), $img_url),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/id_history_converter" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
    'docs' => '',
  });

  ## VIRTUAL MACHINE
  $table->add_row({
    'name' => '<b>Ensembl Virtual Machine</b>',
    'desc' => 'VirtualBox virtual Machine with Ubuntu desktop and pre-configured with the latest Ensembl API plus Variant Effect Predictor (VEP). <b>NB: download is >1 GB</b>',
    'tool' => '-',
    'code' => sprintf('<a href="ftp://ftp.ensembl.org/pub/current_virtual_machine" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Virtual Machine" /></a>', $img_url),
    'docs' => sprintf('<a href="/info/data/virtual_machine.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
  });

  return $table->render;
}

1;
