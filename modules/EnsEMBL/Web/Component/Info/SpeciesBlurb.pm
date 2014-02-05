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

package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Component);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $path              = $hub->species_path;
  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $display_name      = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $ensembl_version   = $species_defs->ENSEMBL_VERSION;
  my $current_assembly  = $species_defs->ASSEMBLY_NAME;
  my $accession         = $species_defs->ASSEMBLY_ACCESSION;
  my $source            = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type       = $species_defs->ASSEMBLY_ACCESSION_TYPE;
  my %archive           = %{$species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {}};
  my %assemblies        = %{$species_defs->get_config($species, 'ASSEMBLIES')       || {}};
  my $previous          = $current_assembly;

  my $html = qq(
<div class="column-wrapper">  
  <div class="column-one">
    <div class="column-padding no-left-margin">
      <a href="$path"><img src="/i/species/48/$species.png" class="species-img float-left" alt="" /></a>
      <h1 class="no-bottom-margin">$common_name assembly and gene annotation</h1>
    </div>
  </div>
</div>
          );

  $html .= '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';
### ASSEMBLY
  $html .= '<h2 id="assembly">Assembly</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_assembly.html");

  $html .= sprintf '<p>The genome assembly represented here corresponds to %s %s</p>', $source_type, $hub->get_ExtURL_link($accession, "ASSEMBLY_ACCESSION_SOURCE_$source", $accession) if $accession; ## Add in GCA link
  
  $html .= '<h2 id="genebuild">Gene annotation</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_annotation.html");

  ## Link to Wikipedia
  $html .= $self->_wikipedia_link; 
  
  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding" style="margin-left:16px">';
    
  ## ASSEMBLY STATS 
  my $file = '/ssi/species/stats_' . $self->hub->species . '.html';
  $html .= '<h2>Statistics</h2>';
  $html .= $self->_stats_tables;

  my $interpro = $self->hub->url({'action' => 'IPtop500'});
  $html .= qq(<h3>InterPro Hits</h3>
<ul>
  <li><a href="$interpro">Table of top 500 InterPro hits</a></li>
</ul>);

  $html .= '
    </div>
  </div>
</div>';

  return $html;  
}

sub _wikipedia_link {
## Factored out so that other sites can override it easily
  my $self = shift;
  my $species = $self->hub->species;
  my $html = qq(<h2>More information</h2>
<p>General information about this species can be found in 
<a href="http://en.wikipedia.org/wiki/$species" rel="external">Wikipedia</a>.
</p>); 

  return $html;
}

sub _stats_tables {
  my $self = shift;
  my $sd = $self->hub->species_defs;
  my $html = '<h3>Summary</h3>';

  my $db_adaptor = $self->hub->database('core');
  my $meta_container = $db_adaptor->get_MetaContainer();
  my $genome_container = $db_adaptor->get_GenomeContainer();

  my %glossary          = $sd->multiX('ENSEMBL_GLOSSARY');
  my %glossary_lookup   = (
      'coding'              => 'Protein coding',
      'shortnoncoding'      => 'Short non coding gene',
      'longnoncoding'       => 'Long non coding gene',
      'pseudogene'          => 'Pseudogene',
      'transcript'          => 'Transcript',
    );


  my $cols = [
    { key => 'name', title => '', width => '30%', align => 'left' },
    { key => 'stat', title => '', width => '70%', align => 'left' },
  ];
  my $options = {'header' => 'no', 'rows' => ['bg3', 'bg1']};

  ## SUMMARY STATS
  my $summary = EnsEMBL::Web::Document::Table->new($cols, [], $options);

  my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
  if ($a_id) {
    # look for long name and accession num
    if (my ($long) = @{$meta_container->list_value_by_key('assembly.long_name')}) {
      $a_id .= " ($long)";
    }
    if (my ($acc) = @{$meta_container->list_value_by_key('assembly.accession')}) {
      $acc = sprintf('INSDC Assembly <a href="http://www.ebi.ac.uk/ena/data/view/%s">%s</a>', $acc, $acc);
      $a_id .= ", $acc";
    }
  }
  $summary->add_row({
      'name' => '<b>Assembly</b>', 
      'stat' => $a_id.', '.$sd->ASSEMBLY_DATE
  });
  $summary->add_row({
      'name' => '<b>Database version</b>', 
      'stat' => $sd->ENSEMBL_VERSION.'.'.$sd->SPECIES_RELEASE_VERSION 
  });
  $summary->add_row({
      'name' => '<b>Base Pairs</b>', 
      'stat' => $self->thousandify($genome_container->get_total_length()),
  });
  $summary->add_row({
      'name' => '<b>Golden Path Length</b>', 
      'stat' => $self->thousandify($genome_container->get_ref_length())
  });
  $summary->add_row({
      'name' => '<b>Genebuild by</b>', 
      'stat' => $sd->GENEBUILD_BY 
  });
  my @A         = @{$meta_container->list_value_by_key('genebuild.method')};
  my $method  = ucfirst($A[0]) || '';
  $method     =~ s/_/ /g;
  $summary->add_row({
      'name' => '<b>Genebuild method</b>', 
      'stat' => $method
  });
  $summary->add_row({
      'name' => '<b>Genebuild started</b>', 
      'stat' => $sd->GENEBUILD_START
  });
  $summary->add_row({
      'name' => '<b>Genebuild released</b>', 
      'stat' => $sd->GENEBUILD_RELEASE
  });
  $summary->add_row({
      'name' => '<b>Genebuild last updated/patched</b>', 
      'stat' => $sd->GENEBUILD_LATEST 
  });
  $summary->add_row({
      'name' => '<b>Gencode version</b>', 
      'stat' => $sd->GENCODE_VERSION
  });

  $html .= $summary->render;   

  ## GENE COUNTS (FOR PRIMARY ASSEMBLY)
  my $counts = EnsEMBL::Web::Document::Table->new($cols, [], $options);
  my @stats = qw(coding snoncoding lnoncoding pseudogene transcript);
  my $has_alt = $genome_container->get_alt_coding_count();

  my $primary = $has_alt ? ' (Primary assembly)' : '';
  $html .= "<h3>Gene counts$primary</h3>";

  foreach (@stats) {
    my $name = $_.'_cnt';
    my $method = 'get_'.$_.'_count';
    my $title = $genome_container->get_attrib($name)->name();
    my $term = $glossary_lookup{$_};
    my $header = $term ? qq(<span class="glossary_mouseover">$title<span class="floating_popup">$glossary{$term}</span></span>) : $title;
    my $stat = $self->thousandify($genome_container->$method);
    unless ($_ eq 'transcript') {
      my $rmethod = 'get_r'.$_.'_count';
      my $readthrough = $genome_container->$rmethod;
      if ($readthrough) {
        $stat .= ' (inc '.$self->thousandify($readthrough).' readthrough)'; 
      }
    }
    $counts->add_row({
      'name' => "<b>$header</b>",
      'stat' => $stat,
    });
  }

  $html .= $counts->render;   

  ## GENE COUNTS FOR ALTERNATE ASSEMBLY
  if ($has_alt) {
    $html .= "<h3>Gene counts (Alternate sequence)</h3>";
    my $alt_counts = EnsEMBL::Web::Document::Table->new($cols, [], $options);
    foreach (@stats) {
      my $name = $_.'_acnt';
      my $method = 'get_alt_'.$_.'_count';
      my $title = $genome_container->get_attrib($name)->name();
      my $term = $glossary_lookup{$_};
      my $header = $term ? qq(<span class="glossary_mouseover">$title<span class="floating_popup">$glossary{$term}</span></span>) : $title;
      my $stat = $self->thousandify($genome_container->$method);
      unless ($_ eq 'transcript') {
        my $rmethod = 'get_r'.$_.'_count';
        my $readthrough = $genome_container->$rmethod;
        if ($readthrough) {
          $stat .= ' (inc '.$self->thousandify($readthrough).' readthrough)'; 
        }
      }
      $alt_counts->add_row({
        'name' => "<b>$header</b>",
        'stat' => $stat,
      });
    }
    $html .= $alt_counts->render;
  }

  ## OTHER STATS
  my $rows = [];
  ## Prediction transcripts
  my $analysis_adaptor = $db_adaptor->get_AnalysisAdaptor();
  my $attribute_adaptor = $db_adaptor->get_AttributeAdaptor();
  my @analyses = @{ $analysis_adaptor->fetch_all_by_feature_class('PredictionTranscript') };
  foreach my $analysis (@analyses) {
    my $logic_name = $analysis->logic_name;
    my $stat = $genome_container->get_prediction_count($logic_name);
    my $name = $attribute_adaptor->fetch_by_code($logic_name)->[2];
    push @$rows, {
      'name' => "<b>$name</b>",
      'stat' => $self->thousandify($stat),
    };
  }
  ## Variants
  my @other_stats = (
    {'name' => 'SNPCount', 'method' => 'get_short_variation_count'},
    {'name' => 'struct_var', 'method' => 'get_structural_variation_count'}
  );
  foreach (@other_stats) {
    my $method = $_->{'method'};
    push @$rows, {
      'name' => '<b>'.$genome_container->get_attrib($_->{'name'})->name().'</b>',
      'stat' => $self->thousandify($genome_container->$method),
    };
  }
  if (scalar(@$rows)) {
    $html .= '<h3>Other</h3>';
    my $other = EnsEMBL::Web::Document::Table->new($cols, $rows, $options);
    $html .= $other->render;
  }

  return $html;
}


1;
