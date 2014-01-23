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
  my $self           = shift;
  my $hub            = EnsEMBL::Web::Hub->new;
  my $sd             = $hub->species_defs;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name', title => 'Name', width => '20%', align => 'left' },
      { key => 'desc', title => 'Description', width => '50%', align => 'left' },
      { key => 'tool', title => 'Online tool', width => '10%', align => 'center' },
      { key => 'code', title => 'Download code', width => '10%', align => 'center' },
      { key => 'docs', title => 'Documentation', width => '10%', align => 'center' },
    ], [], { cellpadding => 4 }
  );

  ## VEP
  $table->add_row({
    'name' => sprintf('<a href="/%s/UserData/UploadVariations" class="modal_link nodeco"><b>Variant Effect Predictor</b><br /><img src="/i/vep_logo_sm.png" alt="[logo]"/></a>', $sd->ENSEMBL_PRIMARY_SPECIES),
    'desc' => 'Analyse your own variants and predict the functional consequences of
known and unknown variants via our Variant Effect Predictor (VEP) tool.',
    'tool' => sprintf('<a href="/%s/UserData/UploadVariations" class="modal_link nodeco"><img src="/i/16/tool.png" alt="Tool" title="Go to online tool" /></a>', $sd->ENSEMBL_PRIMARY_SPECIES),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/variant_effect_predictor" rel="external" class="nodeco"><img src="/i/16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION),
    'docs' => '<a href="/info/docs/tools/vep/index.html"><img src="/i/16/info.png" alt="Documentation" /></a>',
  });

  ## BLAST
  if ($sd->ENSEMBL_BLAST_ENABLED) {
    $table->add_row({
      'name' => '<b><a href="/Multi/blastview">BLAST/BLAT</a></b>',
      'desc' => 'Search our genomes for your DNA or protein sequence.',
      'tool' => '<a href="/Multi/blastview" class="nodeco"><img src="/i/16/tool.png" alt="Tool" title="Go to online tool" /></a>',
      'code' => '',
      'docs' => '<a href="/Help/View?id=196" class="popup"><img src="/i/16/info.png" alt="Documentation" /></a>',
    });
  }

  ## BIOMART
  if ($sd->ENSEMBL_MART_ENABLED) {
    $table->add_row({
      'name' => '<b><a href="/biomart/martview">BioMart</a></b>',
      'desc' => 'Use this data-mining tool to export custom datasets from Ensembl.',
      'tool' => '<a href="/biomart/martview" class="nodeco"><img src="/i/16/tool.png" alt="Tool" title="Go to online tool" /></a>',
      'code' => '<a href="http://biomart.org" rel="external" class="nodeco"><img src="/i/16/download.png" alt="Download" title="Download code from biomart.org" /></a>',
      'docs' => '<a href="http://www.biomart.org/biomart/mview/help.html" class="popup"><img src="/i/16/info.png" alt="Documentation" /></a>',
    });
  }

  ## ASSEMBLY CONVERTER
  $table->add_row({
    'name' => '<b>Assembly converter</b>',
    'desc' => "Map your data to the current assembly's coordinates.",
    'tool' => sprintf('<a href="/%s/UserData/SelectFeatures" class="modal_link nodeco"><img src="/i/16/tool.png" alt="Tool" title="Go to online tool" /></a>', $sd->ENSEMBL_PRIMARY_SPECIES),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/assembly_converter" rel="external" class="nodeco"><img src="/i/16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION),
    'docs' => '',
  });

  ## ID HISTORY CONVERTER
  $table->add_row({
    'name' => '<b>ID History converter</b>',
    'desc' => 'Convert a set of Ensembl IDs from a previous release into their current equivalents.',
    'tool' => sprintf('<a href="/%s/UserData/UploadStableIDs" class="modal_link nodeco"><img src="/i/16/tool.png" alt="Tool" title="Go to online tool" /></a>', $sd->ENSEMBL_PRIMARY_SPECIES),
    'code' => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/id_history_converter" rel="external" class="nodeco"><img src="/i/16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION),
    'docs' => '',
  });

  ## VIRTUAL MACHINE
  $table->add_row({
    'name' => '<b>Ensembl Virtual Machine</b>',
    'desc' => 'VirtualBox virtual Machine with Ubuntu desktop and pre-configured with the latest Ensembl API plus Variant Effect Predictor (VEP). <b>NB: download is >1 GB</b>',
    'tool' => '-',
    'code' => '<a href="ftp://ftp.ensembl.org/pub/current_virtual_machine" rel="external" class="nodeco"><img src="/i/16/download.png" alt="Download" title="Download Virtual Machine" /></a>',
    'docs' => '<a href="/info/data/virtual_machine.html"><img src="/i/16/info.png" alt="Documentation" /></a>',
  });

  return $table->render;
}

1;
