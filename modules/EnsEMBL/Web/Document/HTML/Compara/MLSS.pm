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

package EnsEMBL::Web::Document::HTML::Compara::MLSS;

use strict;

use Math::Round;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

## CONFIGURATION

our $blastz_options = {
  O => 'Gap open penalty',
  E => 'Gap extend penalty',
  K => 'HSP threshold',
  L => 'Threshold for gapped extension',
  H => 'Threshold for alignments between gapped alignment blocks',
  M => 'Masking count',
  T => 'Seed and Transition value',
  Q => 'Scoring matrix',
};

our @blastz_order = qw(O E K L H M T Q); 

our $blastz_parameters = {
  O => 400,
  E => 30,
  K => 3000,
  T => 1,
};

our $tblat_options = {
  minScore => 'Minimum score',
  t        => 'Database type',
  q        => 'Query type',
  mask     => 'Mask out repeats',
  qMask    => 'Mask out repeats on query',     
};

our @tblat_order = qw(minScore t q mask qMask);

our %pretty_method = (
  BLASTZ_NET          => 'BlastZ',
  LASTZ_NET           => 'LastZ',
  TRANSLATED_BLAT_NET => 'Translated Blat',
  SYNTENY             => 'Synteny',
);

our $references = {
  'Translated Blat' => qq{<a href="http://www.genome.org/cgi/content/abstract/12/4/656\">Kent W, Genome Res., 2002;12(4):656-64</a>},
  'LastZ'           => qq{<a href="http://www.bx.psu.edu/miller_lab/dist/README.lastz-1.02.00/README.lastz-1.02.00a.html">LastZ</a>},
  'BlastZ'          => qq{
    <a href="http://www.genome.org/cgi/content/abstract/13/1/103">Schwartz S et al., Genome Res.;13(1):103-7</a>, 
    <a href="http://www.pnas.org/cgi/content/full/100/20/11484">Kent WJ et al., Proc Natl Acad Sci U S A., 2003;100(20):11484-9</a>
  }
};

## HTML OUTPUT ######################################

sub render { 
  my $self    = shift;
  my $hub     = $self->hub;
  my $mlss_id = $hub->param('mlss');
  my $site    = $hub->species_defs->ENSEMBL_SITETYPE;
  my $html;

  my ($alignment_results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config) = $self->fetch_input($mlss_id);

  my $ref_sp          = $ref_dna_collection_config->{'name'};
  my $ref_common      = $ref_dna_collection_config->{'common_name'};
  my $ref_assembly    = $ref_results->{'assembly'};
  my $nonref_sp       = $non_ref_dna_collection_config->{'name'};
  my $nonref_common   = $non_ref_dna_collection_config->{'common_name'};
  my $nonref_assembly = $non_ref_results->{'assembly'};
  my $release         = $pair_aligner_config->{'ensembl_release'};
  my $type            = $pretty_method{$pair_aligner_config->{'method_link_type'}};

  ## HEADER AND INTRO
  $html .= sprintf('<h1>%s vs %s %s Results</h1>',
                        $ref_common, $nonref_common, $type,
            );

  if ($pair_aligner_config->{'download_url'}) {
    my $ucsc = $pair_aligner_config->{'download_url'};
    $html .= qq{<p>$ref_common (<i>$ref_sp</i>, $ref_assembly) and $nonref_common (<i>$nonref_sp</i>, $nonref_assembly)
alignments were downloaded from <a href="$ucsc">UCSC</a> in $site release $release.</p>};
  }
  elsif ($type eq 'Synteny') {
    $html .= sprintf '<p>The syntenic regions between %s (<i>%s</i>, %s) and %s (<i>%s</i>, %s) were extracted from their pairwise alignment in %s release %s.
    We look for stretches where the alignment blocks are in synteny. The search is run in two phases.
    In the first one, syntenic alignments that are closer than 200 kbp are grouped.
    In the second phase, the groups that are in synteny are linked provided that no more than 2 non-syntenic groups are found between them and they are less than 3Mbp apart.</p>',
              $ref_common, $ref_sp, $ref_assembly, $nonref_common, $nonref_sp, $nonref_assembly,
              $site, $release;
  } else {
    $html .= sprintf '<p>%s (<i>%s</i>, %s) and %s (<i>%s</i>, %s) were aligned using the %s alignment algorithm (%s)
in %s release %s. %s was used as the reference species. After running %s, the raw %s alignment blocks
are chained according to their location in both genomes. During the final netting process, the best
sub-chain is chosen in each region on the reference species.</p>',
              $ref_common, $ref_sp, $ref_assembly, $nonref_common, $nonref_sp, $nonref_assembly,
              $type, $references->{$type}, $site, $release, $ref_common, $type, $type;
  }

  $html .= '<h2>Configuration parameters</h2>';

  ## CONFIG TABLE
  if (keys %$blastz_parameters || keys %$tblat_parameters) {
    my ($rows, $options, @order, $params);
    my $columns = [
      { key => 'param', title => 'Parameter' },
      { key => 'value', title => 'Value'     },
    ];
    
    if ($type eq 'Translated Blat') {
      $options = $tblat_options;
      @order   = @tblat_order;
      $params  = $tblat_parameters;
    } else {
      $options = $blastz_options;
      @order   = @blastz_order;
      $params  = $blastz_parameters;
    }

    push @$rows, { param => "$options->{$_} ($_)", value => $params->{$_} || ($_ eq 'Q' ? 'Default' : '') } for @order;

    $html .= EnsEMBL::Web::Document::Table->new($columns, $rows)->render;
  } else {
    $html .= '<p>No configuration parameters are available.</p>';
  }

  ## CHUNKING TABLE
  if ($ref_dna_collection_config->{'chunk_size'}) {
    my @rows;
    my @columns = (
      { key => 'param',        title => 'Parameter'    },
      { key => 'value_ref',    title => $ref_common    },
      { key => 'value_nonref', title => $nonref_common },
    );

    my @params = qw(chunk_size overlap group_set_size masking_options);

    foreach my $param (@params) {
      my $header = ucfirst $param;
         $header =~ s/_/ /g;
      my ($value_1, $value_2);
      
      if ($param eq 'masking_options') {
        $value_1 = $ref_dna_collection_config->{$param}     || '';
        $value_2 = $non_ref_dna_collection_config->{$param} || '';
      } else {
        $value_1 = $self->thousandify($ref_dna_collection_config->{$param})     || 0;
        $value_2 = $self->thousandify($non_ref_dna_collection_config->{$param}) || 0;
      }
      
      push @rows, { param => $header, value_ref => $value_1, value_nonref => $value_2 };
    } 

    $html .= '<h2>Chunking parameters</h2>';
    $html .= EnsEMBL::Web::Document::Table->new(\@columns, \@rows)->render;
  }

  my $blocks = $self->thousandify($alignment_results->{'num_blocks'});
  my $block_type = $type eq 'Synteny' ? 'synteny' : 'alignment';
  $html .= qq{
    <h2>Statistics over $blocks $block_type blocks</h2>
    };

  ## PIE CHARTS
  $html .= qq{
    <div class="js_panel">
  };

  my $graph_defaults = qq{
      <input class="panel_type" type="hidden" value="Piechart" />
      <input class="graph_config" type="hidden" name="stroke" value="'#999'" />
      <input class="graph_config" type="hidden" name="legendpos" value="'east'" />
      <input class="graph_dimensions" type="hidden" value="[80,80,75]" />
      <input class="graph_config" type="hidden" name="colors" value="['#dddddd','#6699ff','#ffcc00','#990099']" />
  };
  my $key = {};
  my $i = 0;

  ## Genome coverage charts
  $html .= qq{
    <div>
      $graph_defaults
  };

  foreach my $sp ($ref_sp, $nonref_sp) {
    my $results = $i ? $non_ref_results : $ref_results; 
    my $sp_type = $i ? 'non_ref' : 'ref';

    my $total     = $results->{'length'};
    if ($total) {
      my $coverage  = $results->{"alignment_coverage"};
      my $inverse   = $total - $coverage;

      $key->{$sp_type}{'genome'} = sprintf('<p>
                                              <b>Uncovered</b>: %s out of %s<br />
                                              <b>Covered</b>: %s out of %s
                                            </p>',
                                $self->thousandify($inverse), $self->thousandify($total),
                                $self->thousandify($coverage), $self->thousandify($total),
                                );

      my $percent  = round($coverage/$total * 100);
      my $invperc  = 100 - $percent;
      $html .= qq{
          <input class="graph_data" type="hidden" value="[[$invperc||.001,'Uncovered'],[$percent||.001, 'Covered']]" />
      };
    }
    $i++;
  }
  $html .= '</div>';

  ##Exon coverage charts
  $i = 0;
  $html .= qq{
    <div>
      $graph_defaults
  };

  foreach my $sp ($ref_sp, $nonref_sp) {
    my $results = $i ? $non_ref_results : $ref_results; 
    my $sp_type = $i ? 'non_ref' : 'ref';

    my $total         = $results->{'coding_exon_length'};
    if ($total) { 
      my $matches     = $results->{'matches'};
      my $mismatches  = $results->{'mis-matches'};
      my $insertions  = $results->{'insertions'};
      my $covered     = $results->{'covered'};
      my $uncovered   = $results->{'uncovered'};

      if ($type eq 'Synteny') {
        $key->{$sp_type}{'exon'} = sprintf(
          '<p>
            <b>Uncovered</b>: %s out of %s<br />
            <b>Covered</b>: %s out of %s<br />
          </p>',
          $self->thousandify($uncovered), $self->thousandify($total),
          $self->thousandify($covered), $self->thousandify($total),
        );

        my $cov_pc  = round($covered/$total * 100);
        my $uncov_pc  = 100 - $cov_pc;

        $html .= qq{
            <input class="graph_data" type="hidden" value="[[$uncov_pc||.001,'Uncovered'],[$cov_pc||.001, 'Covered'],]" />
        };
      } else {

        $key->{$sp_type}{'exon'} = sprintf(
          '<p>
            <b>Uncovered</b>: %s out of %s<br />
            <b>Matches</b>: %s out of %s<br />
            <b>Mismatches</b>: %s out of %s<br />
            <b>Insertions</b>: %s out of %s
          </p>',
          $self->thousandify($uncovered), $self->thousandify($total),
          $self->thousandify($matches), $self->thousandify($total),
          $self->thousandify($mismatches), $self->thousandify($total),
          $self->thousandify($insertions), $self->thousandify($total),
        );

        my $match_pc  = round($matches/$total * 100);
        my $mis_pc    = round($mismatches/$total * 100);
        my $ins_pc    = round($insertions/$total * 100);
        my $uncov_pc  = 100 - ($match_pc + $mis_pc + $ins_pc);

        $html .= qq{
          <input class="graph_data" type="hidden" value="[[$uncov_pc||.001,'Uncovered'],[$match_pc||.001, 'Matches'],[$mis_pc||.001,'Mismatches'],[$ins_pc||.001,'Insertions']]" />
        };
      }
    }
    $i++;
  }
  $html .= '</div>';

  ## Draw table
  my $graph_style = 'width:300px;height:160px;margin:0 auto';
  $html .= sprintf(
    '<table style="width:100%">
      <tr>
        <th></th>
        <th style="text-align:center">Genome coverage (bp)</th>
        <th style="text-align:center">Coding exon coverage (bp)</th>
      </tr>
      <tr>
        <th style="vertical-align:middle">%s</th>
        <td style="text-align:center;padding:12px">
          <div id="graphHolder0" style="%s"></div>%s
        </td>
        <td style="text-align:center;padding:12px">
          <div id="graphHolder2" style="%s"></div>%s
        </td>
      </tr>
      <tr>
        <th style="vertical-align:middle">%s</th>
        <td style="text-align:center;padding:12px">
          <div id="graphHolder1" style="%s"></div>%s
        </td>
        <td style="text-align:center;padding:12px">
          <div id="graphHolder3" style="%s"></div>%s
        </td>
      </tr>
    </table>',
    $ref_common,
    $graph_style, $key->{'ref'}{'genome'}, 
    $graph_style, $key->{'ref'}{'exon'}, 
    $nonref_common,
    $graph_style, $key->{'non_ref'}{'genome'}, 
    $graph_style, $key->{'non_ref'}{'exon'}, 
  );

  $html .= '</div>';

  return $html;
}

## HELPER METHODS ##################################

sub fetch_input {
  my ($self, $mlss_id) = @_;
  
  return unless $mlss_id;
  
  my $hub        = $self->hub;
  my $compara_db = $hub->database('compara');
  my ($results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);
  
  if ($compara_db) {
    my $genome_db_adaptor             = $compara_db->get_adaptor('GenomeDB');
    my $mlss                          = $compara_db->get_adaptor('MethodLinkSpeciesSet')->fetch_by_dbID($mlss_id);
    my $num_blocks                    = $mlss->get_value_for_tag('num_blocks');
    my $ref_species                   = $mlss->get_value_for_tag('reference_species');
    my $non_ref_species               = $mlss->get_value_for_tag('non_reference_species');
    my $pairwise_params               = $mlss->get_value_for_tag('param');
    my $ref_genome_db                 = $genome_db_adaptor->fetch_by_name_assembly($ref_species);
    my $non_ref_genome_db             = $genome_db_adaptor->fetch_by_name_assembly($non_ref_species);
      
    ## hack for double-quotes
    my $string_ref_dna_collection_config  = $mlss->get_value_for_tag("ref_dna_collection");
    if ($string_ref_dna_collection_config) {
       $string_ref_dna_collection_config =~ s/\"/\'/g;
       $ref_dna_collection_config = eval $string_ref_dna_collection_config;
    }
    my $string_non_ref_dna_collection_config  = $mlss->get_value_for_tag("non_ref_dna_collection");
    if ($string_non_ref_dna_collection_config) {
       $string_non_ref_dna_collection_config =~ s/\"/\'/g;
       $non_ref_dna_collection_config = eval $string_non_ref_dna_collection_config;
    }
 
    $results->{'num_blocks'} = $num_blocks;
    
    $ref_results->{'name'}                    = $ref_genome_db->name;
    $ref_results->{'assembly'}                = $ref_genome_db->assembly;
    $ref_results->{'length'}                  = $mlss->get_value_for_tag('ref_genome_length');
    $ref_results->{'alignment_coverage'}      = $mlss->get_value_for_tag('ref_genome_coverage');
    $ref_results->{'coding_exon_length'}      = $mlss->get_value_for_tag('ref_coding_exon_length');
    $ref_results->{'matches'}                 = $mlss->get_value_for_tag('ref_matches');
    $ref_results->{'mis-matches'}             = $mlss->get_value_for_tag('ref_mis_matches');
    $ref_results->{'insertions'}              = $mlss->get_value_for_tag('ref_insertions');
    $ref_results->{'covered'}                 = $mlss->get_value_for_tag('ref_covered');
    $ref_results->{'uncovered'}               = $mlss->get_value_for_tag('ref_uncovered');

    
    $non_ref_results->{'name'}                    = $non_ref_genome_db->name;
    $non_ref_results->{'assembly'}                = $non_ref_genome_db->assembly;
    $non_ref_results->{'length'}                  = $mlss->get_value_for_tag('non_ref_genome_length');
    $non_ref_results->{'alignment_coverage'}      = $mlss->get_value_for_tag('non_ref_genome_coverage');
    $non_ref_results->{'coding_exon_length'}      = $mlss->get_value_for_tag('non_ref_coding_exon_length');
    $non_ref_results->{'matches'}                 = $mlss->get_value_for_tag('non_ref_matches');
    $non_ref_results->{'mis-matches'}             = $mlss->get_value_for_tag('non_ref_mis_matches');
    $non_ref_results->{'insertions'}              = $mlss->get_value_for_tag('non_ref_insertions');
    $non_ref_results->{'covered'}                 = $mlss->get_value_for_tag('non_ref_covered');
    $non_ref_results->{'uncovered'}               = $mlss->get_value_for_tag('non_ref_uncovered');

    $pair_aligner_config->{'method_link_type'} = $mlss->method->type;
    $pair_aligner_config->{'ensembl_release'}  = $mlss->get_value_for_tag('ensembl_release');
    $pair_aligner_config->{'download_url'}     = $mlss->url if $mlss->source eq 'ucsc';
    
    $ref_dna_collection_config->{'name'}        = $self->sci_name($ref_species);
    $ref_dna_collection_config->{'common_name'} = $self->common_name($ref_genome_db->name);
    
    $non_ref_dna_collection_config->{'name'}        = $self->sci_name($non_ref_genome_db->name);
    $non_ref_dna_collection_config->{'common_name'} = $self->common_name($non_ref_genome_db->name);
    
    if ($mlss->method->type eq 'TRANSLATED_BLAT_NET') {
      foreach my $param (split ' ', $pairwise_params) {
        my ($p, $v) = split '=', $param;
        $p =~ s/-//;
        $tblat_parameters->{$p} = $v;
      }
    } elsif ($mlss->method->type =~ /LASTZ_NET/) {
      foreach my $param (split ' ', $pairwise_params) {
        my ($p, $v) = split '=', $param;
        
        if ($p eq 'Q' && $v =~ /^\/nfs/) {
          ## slurp in the matrix file
          my @path  = split '/', $v;
          my $file  = $path[-1];
          my $fh    = open IN, $hub->species_defs->ENSEMBL_SERVERROOT . "/public-plugins/ensembl/htdocs/info/genome/compara/$file";
          
          $v  = '<pre>';
          while (<IN>) {
            $v .= $_;
          }
          $v .= '</pre>';
        }
        
        if ($blastz_options->{$p}) {
          $blastz_parameters->{$p} = $v;
        } else {
          $blastz_parameters->{'other'} .= $param;
        }
      }
      ## Set default matrix
      unless ($blastz_parameters->{'Q'}) {
        my $fh    = open IN, $hub->species_defs->ENSEMBL_SERVERROOT . "/public-plugins/ensembl/htdocs/info/genome/compara/default.matrix";
        my $v  = '<pre>Default:
';
        while (<IN>) {
          $v .= $_;
        }
        $v .= '</pre>';
        $blastz_parameters->{'Q'} = $v;
      }
    }
  }
  
  return ($results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);
}

1;
