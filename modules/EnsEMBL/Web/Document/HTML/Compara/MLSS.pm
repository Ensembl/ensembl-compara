package EnsEMBL::Web::Document::HTML::Compara::MLSS;

use strict;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

## CONFIGURATION

our $blastz_options = {
        'O' => "Gap open penalty (O)",
        'E' => "Gap extend penalty (E)",
        'K' => "HSP threshold (K)",
        'L' => "Threshold for gapped extension (L)",
        'H' => "Threshold for alignments between gapped alignment blocks (H)",
        'M' => "Masking count (M)",
        'T' => "Seed and Transition value (T)",
        'Q' => "Scoring matrix (Q)"
};
our @blastz_order = (qw(O E K L H M T Q)); 

our $blastz_parameters = {
          'O' => 400,
          'E' => 30,
          'K' => 3000,
          'T' => 1
};

our %pretty_method = (
    'BLASTZ_NET' => 'BlastZ',
    'LASTZ_NET'  => 'LastZ',
    'TRANSLATED_BLAT_NET' => 'Translated Blat',
);

our $references = {
       BlastZ => "<a href=\"http://www.genome.org/cgi/content/abstract/13/1/103\">Schwartz S et al., Genome Res.;13(1):103-7</a>, <a href=\"http://www.pnas.org/cgi/content/full/100/20/11484\">Kent WJ et al., Proc Natl Acad Sci U S A., 2003;100(20):11484-9</a>",

       LastZ => "<a href=\"http://www.bx.psu.edu/miller_lab/dist/README.lastz-1.02.00/README.lastz-1.02.00a.html\">LastZ</a>",
       "Translated Blat" => "<a href=\"http://www.genome.org/cgi/content/abstract/12/4/656\">Kent W, Genome Res., 2002;12(4):656-64</a>"};

## HTML OUTPUT ######################################

sub render { 
  my $self = shift;
  my $hub = EnsEMBL::Web::Hub->new;
  $self->hub = $hub;
  my $mlss_id = $hub->param('mlss');
  my $method  = $hub->param('method');
  my $type    = $pretty_method{$method};
  my $site    = $hub->species_defs->ENSEMBL_SITETYPE;
  my $release = $hub->species_defs->VERSION;
  my $html;

  my ($alignment_results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config) = $self->fetch_input($mlss_id);

  my $ref_sp        = $ref_dna_collection_config->{name};
  my $ref_common    = $ref_dna_collection_config->{common_name};
  my $ref_assembly  = $ref_results->{assembly};
  my $nonref_sp     = $non_ref_dna_collection_config->{name};
  my $nonref_common = $non_ref_dna_collection_config->{common_name};
  my $nonref_assembly  = $non_ref_results->{assembly};

  $html .= sprintf('<h1>%s vs %s %s alignments</h1>', 
                        $ref_common, $nonref_common, $pretty_method{$method},
            );


  $html .= qq{<p>$ref_common (<i>$ref_sp</i>, $ref_assembly) and $nonref_common (<i>$nonref_sp</i>, $nonref_assembly) 
were aligned using the $type alignment algorithm};
  $html .= ' ('.$references->{$type}.')' unless $pair_aligner_config->{download_url};
  $html .= qq{ in $site release $release. $ref_common was used as the reference species. After running $type, 
the raw $type alignment blocks are chained according to their location in both genomes. During the final 
netting process, the best sub-chain is chosen in each region on the reference species.</p>};

  $html .= '<h2>Configuration parameters</h2>';

  my $columns = [
    {'key' => 'param', 'title' => 'Parameter'},
    {'key' => 'value', 'title' => 'Value'},
  ];

  my $rows;
  foreach my $k (@blastz_order) {
    my $v = $blastz_options->{$k};
    push @$rows, {'param' => $v, 'value' => $blastz_parameters->{$k}};
  }

  my $table = EnsEMBL::Web::Document::Table->new($columns, $rows);
  $html .= $table->render;

  $html .= '<h2>Results</h2>';

  $html .= '<p>Number of alignment blocks: '.$alignment_results->{num_blocks}.'</p>';

  $html .= '<table>
<tr>
<th></th>
<th style="text-align:center">Genome coverage (bp)</th>
<th style="text-align:center">Coding exon coverage (bp)</th>
</tr>
';

  my $i = 0;
  my $n = 1;
  foreach my $sp ($ref_sp, $nonref_sp) {
    $html .= qq(<tr><th style="vertical-align:middle">$sp</th>);
    my $results = $i ? $non_ref_results : $ref_results; 

    foreach my $coverage ('alignment', 'alignment_exon') {
      $html .= '<td style="padding:12px">';
      $html .= sprintf '<div id="graphHolder%s" style="width:200px;height:200px"></div>', $i;
      $html .= $self->thousandify($results->{$coverage.'_coverage'}).' out of '
                .$self->thousandify($results->{'length'});
      $html .= '</td>';
    }

    $html .= '</tr>';
    $i++;
    $n++;
  }

  $html .= '</table>';

  return $html;
}

## HELPER METHODS ##################################

sub fetch_input {
  my ($self, $mlss_id) = @_;
  return unless ($mlss_id);
  my $hub = $self->hub;

  my ($results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);

  my $compara_db = $hub->database('compara');
  if ($compara_db) {
    my $genome_db_adaptor = $compara_db->get_adaptor('GenomeDB');
    my $mlss              = $compara_db->get_adaptor('MethodLinkSpeciesSet')->fetch_by_dbID($mlss_id);

    my $num_blocks = $mlss->get_value_for_tag("num_blocks");

    $results->{num_blocks} = $num_blocks;

    my $ref_species = $mlss->get_value_for_tag("reference_species");
    my $non_ref_species = $mlss->get_value_for_tag("non_reference_species");

    my $ref_genome_db = $genome_db_adaptor->fetch_by_name_assembly($ref_species);
    $ref_results->{name} = $ref_genome_db->name;
    $ref_results->{assembly} = $ref_genome_db->assembly;

    $ref_results->{length} = $mlss->get_value_for_tag("ref_genome_length");
    $ref_results->{coding_exon_length} = $mlss->get_value_for_tag("ref_coding_length");;
    $ref_results->{alignment_coverage} = $mlss->get_value_for_tag("ref_genome_coverage");
    $ref_results->{alignment_exon_coverage} = $mlss->get_value_for_tag("ref_coding_coverage");

    my $non_ref_genome_db = $genome_db_adaptor->fetch_by_name_assembly($non_ref_species);
    $non_ref_results->{name} = $non_ref_genome_db->name;
    $non_ref_results->{assembly} = $non_ref_genome_db->assembly;

    $non_ref_results->{length} = $mlss->get_value_for_tag("non_ref_genome_length");
    $non_ref_results->{coding_exon_length} = $mlss->get_value_for_tag("non_ref_coding_length");;
    $non_ref_results->{alignment_coverage} = $mlss->get_value_for_tag("non_ref_genome_coverage");
    $non_ref_results->{alignment_exon_coverage} = $mlss->get_value_for_tag("non_ref_coding_coverage");

    $pair_aligner_config->{method_link_type} = $mlss->method->type;

    $pair_aligner_config->{ensembl_release} = $mlss->get_value_for_tag("ensembl_release");

    if ($mlss->source eq "ucsc") {
      $pair_aligner_config->{download_url} = $mlss->url;
    }

    my $pairwise_params = $mlss->get_value_for_tag("param");
    if ($mlss->method->type eq "TRANSLATED_BLAT_NET") {
      unless (defined $pairwise_params) {
        $tblat_parameters = {};
      }
      my @params = split " ", $pairwise_params;
      foreach my $param (@params) {
        my ($p, $v) = split "=", $param;
        $p =~ s/-//;
        $tblat_parameters->{$p} = $v;
      }
    } 
    else {
      unless (defined $pairwise_params) {
        $blastz_parameters = {};
      }

      my @params = split " ", $pairwise_params;
      foreach my $param (@params) {
        my ($p, $v) = split "=", $param;
        if ($blastz_options->{$p}) {
          $blastz_parameters->{$p} = $v;
        } 
        else {
          $blastz_parameters->{other} .= $param;
        }
      }
    }


    $ref_dna_collection_config = eval $mlss->get_value_for_tag("ref_dna_collection");
    $ref_dna_collection_config->{name} = $self->sci_name($ref_species);
    my $ref_common_name = $self->common_name($ref_genome_db->name);
    $ref_dna_collection_config->{common_name} = $ref_common_name;

    $non_ref_dna_collection_config = eval $mlss->get_value_for_tag("non_ref_dna_collection");
    $non_ref_dna_collection_config->{name} = $self->sci_name($non_ref_genome_db->name);
    my $non_ref_common_name = $self->common_name($non_ref_genome_db->name);
    $non_ref_dna_collection_config->{common_name} = $non_ref_common_name;
  }
  return ($results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);
}

1;
