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

package EnsEMBL::Web::Document::HTML::ToolsTable;

### Allows easy removal of items from template

use strict;

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self    = shift;
  my $hub     = $self->hub;
  my $sd      = $hub->species_defs;
  my $sp      = $sd->ENSEMBL_PRIMARY_SPECIES;
  my $img_url = $sd->img_url;

  my $sitename = $sd->ENSEMBL_SITETYPE;
  my $html = '<h2>Processing your data</h2>';

  ## Table for online tools
  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name',  title => 'Name',            width => '20%', align => 'left' },
      { key => 'desc',  title => 'Description',     width => '40%', align => 'left' },
      { key => 'tool',  title => 'Online tool',     width => '10%', align => 'center' },
      { key => 'limit', title => 'Upload limit',    width => '10%', align => 'center' },
      { key => 'code',  title => 'Download script', width => '10%', align => 'center' },
      { key => 'docs',  title => 'Documentation',   width => '10%', align => 'center' },
    ], [], { cellpadding => 4 }
  );

  my $tools_limit = '50MB';

  ## VEP
  if ($sd->ENSEMBL_VEP_ENABLED) {
    my $vep_link = $hub->url({'species' => $sp, 'type' => 'Tools', 'action' =>  'VEP'});
    $table->add_row({
      'name'  => sprintf('<a href="%s" class="nodeco"><b>Variant Effect Predictor</b><br /><img src="%svep_logo_sm.png" alt="[logo]" /></a>', $vep_link, $img_url),
      'desc'  => 'Analyse your own variants and predict the functional consequences of known and unknown variants via our Variant Effect Predictor (VEP) tool.',
      'limit' => $tools_limit.'*',
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $vep_link, $img_url),
      'code'  => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/archive/release/%s.zip" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
      'docs'  => sprintf('<a href="/info/docs/tools/vep/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
    });
  }

  ## VR
  if ($sd->ENSEMBL_VR_ENABLED) {
    my $vr_link = $hub->url({'species' => $sp, 'type' => 'Tools', 'action' =>  'VR'});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Variant Recoder</a></b>', $vr_link),
      'desc'  => 'Translate a variant identifier, HGVS notation or genomic SPDI notation to all possible variant IDs, HGVS, VCF format and genomic SPDI.',
      'limit' => 'Maximun 1000 variants recommended',
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $vr_link, $img_url),
      'code'  => sprintf('<a href="https://github.com/Ensembl/ensembl-vep/tree/release/%s/variant_recoder" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
      'docs'  => sprintf('<a href="/info/docs/tools/vep/recoder/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
    });
  }

  ## BLAST
  if ($sd->ENSEMBL_BLAST_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action Blast)});
    my %tools = @{$sd->ENSEMBL_TOOLS_LIST};
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">%s</a></b>', $link, $tools{'Blast'}),
      'desc'  => 'Search our genomes for your DNA or protein sequence.',
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => $tools_limit,
      'code'  => '',
      'docs'  => sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/Blast'}}), $img_url)
    });
  }

  ## File chameleon
  if ($sd->ENSEMBL_FC_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action FileChameleon)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">File Chameleon</a></b>', $link),
      'desc'  => "Convert Ensembl files for use with other analysis tools",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'code'  => sprintf('<a href="https://github.com/FAANG/faang-format-transcriber" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $img_url),
      'docs'  =>  sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/FileChameleon'}}), $img_url),
    });
  }

  ## ASSEMBLY CONVERTER
  if ($sd->ENSEMBL_AC_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action AssemblyConverter)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Assembly Converter</a></b>', $link),
      'desc'  => "Map (liftover) your data's coordinates to the current assembly.",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => $tools_limit,
      'code'  => '',
      'docs'  =>  sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/AssemblyConverter'}}), $img_url),
    });
  }

  ## ID HISTORY CONVERTER
  if ($sd->ENSEMBL_IDM_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action IDMapper)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">ID History Converter</a></b>', $link),
      'desc'  => 'Convert a set of Ensembl IDs from a previous release into their current equivalents.',
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => $tools_limit,
      'code'  => sprintf('<a href="https://github.com/Ensembl/ensembl-tools/tree/release/%s/scripts/id_history_converter" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $sd->ENSEMBL_VERSION, $img_url),
      'docs'  =>  sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/IDMapper'}}), $img_url),
    });
  }

  ## Linkage Disequilibrium Calculator
  if ($sd->ENSEMBL_LD_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action LD)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Linkage Disequilibrium Calculator</a></b>', $link),
      'desc'  => 'Calculate LD between variants using genotypes from a selected population.',
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'code'  => '',
      'docs'  =>  sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/LD'}}), $img_url),
    });
  }

  ## Allele frequency
  if ($sd->ENSEMBL_AF_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action AlleleFrequency)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Allele frequency calculator</a></b>', $link),
      'desc'  => "This tool calculates population-wide allele frequency for sites within the chromosomal region defined from a VCF file and populations defined in a sample panel file.",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'code'  => sprintf('<a href="https://raw.githubusercontent.com/Ensembl/1000G-tools/master/allelefrequency/calculate_allele_frq_from_vcf.pl" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $img_url),
      'docs'  => sprintf('<a href="/info/docs/tools/allelefrequency/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url),
    });
  }

  ## VCF to PED
  if ($sd->ENSEMBL_VP_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action VcftoPed)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">VCF to PED converter</a></b>', $link),
      'desc'  => "Parse a vcf file to create a linkage pedigree file (ped) and a marker information file, which together may be loaded into ld visualization tools like Haploview.",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'code'  => sprintf('<a href="http://http.1000genomes.ebi.ac.uk/vol1/ftp/technical/browser/vcf_to_ped_converter/version_1.1/vcf_to_ped_convert.pl" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $img_url),
      'docs'  => sprintf('<a href="/info/docs/tools/vcftoped/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url),
    });
  }

  ## Data Slicer
  if ($sd->ENSEMBL_DS_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action DataSlicer)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Data Slicer</a></b>', $link),
      'desc'  => "Get a subset of data from a BAM or VCF file.",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'docs'  => sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/DataSlicer'}}), $img_url),
    });
  }

  ## Variation Pattern finder
  if ($sd->ENSEMBL_VPF_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action VariationPattern)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Variation Pattern Finder</a></b>', $link),
      'desc'  => "Identify variation patterns in a chromosomal region of interest for different individuals. Only variations with functional significance such non-synonymous coding, splice site will be reported by the tool.",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'code'  => sprintf('<a href="http://http.1000genomes.ebi.ac.uk/vol1/ftp/technical/browser/variation_pattern_finder/version_1.0" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Download Perl script" /></a>', $img_url),
      'docs'  => sprintf('<a href="/info/docs/tools/variationpattern/index.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url),
    });
  }

  ## Postgap
  if ($sd->ENSEMBL_PG_ENABLED) {
    my $link = $hub->url({'species' => $sp, qw(type Tools action Postgap)});
    $table->add_row({
      'name'  => sprintf('<b><a class="nodeco" href="%s">Post-GWAS</a></b>', $link),
      'desc'  => "Upload GWAS summary statistics and highlight likely causal gene candidates.",
      'tool'  => sprintf('<a href="%s" class="nodeco"><img src="%s16/tool.png" alt="Tool" title="Go to online tool" /></a>', $link, $img_url),
      'limit' => '',
      'code'  => sprintf('<a href="https://github.com/Ensembl/postgap/" rel="external" class="nodeco"><img src="%s16/download.png" alt="Download" title="Github repo" /></a>', $img_url),
      'docs'  => sprintf('<a href="/%s" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $hub->url({'species' => '', 'type' => 'Help', 'action' => 'View', 'id' => { $sd->multiX('ENSEMBL_HELP') }->{'Tools/Postgap'}}), $img_url),
    });
  }  


  if ($table->has_rows) {
    $html .= $table->render;
    $html .= '* For larger datasets we provide an API script that can be downloaded (you will also need to install our Perl API, below, to run the script).';

  }
  else {
    $html .= '<p><b>No tools are available on this site. Please visit <a href="//www.ensembl.org/info/docs/tools/">our main site</a> for more options.</b></p>';
  }

  ## Table of other tools
  my $ftp = $sd->ENSEMBL_FTP_URL;

  if ($sd->HAS_API_DOCS || $sd->ENSEMBL_MART_ENABLED || $sd->ENSEMBL_REST_URL) {
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
        'docs' => sprintf('<a href="/info/data/biomart/index.html" class="popup"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
      });
    }
  
    ## PERL API
    if ($sd->HAS_API_DOCS) { 
      $table->add_row({
        'name' => '<b>Ensembl Perl API</b>',
        'desc' => 'Programmatic access to all Ensembl data using simple Perl scripts',
        'from' => qq(<a href="https://github.com/Ensembl">GitHub</a> or <a href="$ftp/ensembl-api.tar.gz" rel="external">FTP download</a> (current release only)),
        'docs' => sprintf('<a href="/info/docs/api/"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
      });

      ## VIRTUAL MACHINE
      $table->add_row({
        'name' => '<b>Ensembl Virtual Machine</b>',
        'desc' => 'VirtualBox virtual Machine with Ubuntu desktop and pre-configured with the latest Ensembl API plus Variant Effect Predictor (VEP). <b>NB: download is >1 GB</b>',
        'from' => qq(<a href="$ftp/current_virtual_machine" rel="external">FTP download</a>),
        'docs' => sprintf('<a href="/info/data/virtual_machine.html"><img src="%s16/info.png" alt="Documentation" /></a>', $img_url)
      });
    }

    ## REST
    my $rest_url = $sd->ENSEMBL_REST_URL;
    my $is_internal = $sd->ENSEMBL_REST_INTERNAL_ONLY;
    if ($rest_url && !$is_internal) {
      my $rest_domain = $rest_url =~ s/(https?:)?\/\///r;
      $table->add_row({
        "name" => sprintf("<b><a href=%s>$sitename REST server</a></b>", $rest_url),
        'desc' => 'Access Ensembl data using your favourite programming language',
        "from" => sprintf('<a href="%s">%s</a>', $rest_url, $rest_domain),
        'docs' => sprintf('<a href="%s"><img src="%s16/info.png" alt="Documentation" /></a>', $sd->ENSEMBL_REST_DOC_URL || $rest_url, $img_url)
      });
    }

    $html .= $table->render;
  }

  return $html;
}

1;
