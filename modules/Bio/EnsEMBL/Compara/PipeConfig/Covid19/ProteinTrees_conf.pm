=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Covid19::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Covid19::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id <curr_ptree_mlss_id>

=head1 DESCRIPTION

The Covid19 PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Covid19::ProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'        => 'covid19',
        'prev_rel_db'     =>  undef,

        'clustering_mode' => 'blastp',
        'paf_exp_proportion' => 0.9,

        # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
        # values were infered by checking previous releases, values that are out of these ranges may be caused by assembly and/or gene annotation problems.
        'mapped_gene_ratio_per_taxon' => {
            '2559587' => 0.75,     #Riboviria
        },

        # define blast parameters and evalues for ranges of sequence-length
        # Important note: -max_hsps parameter is only available on ncbi-blast-2.3.0 or higher.
        'all_blast_params'          => [
            [ 0,   35,       '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM30 -word_size 2',    '10' ],
            [ 35,  50,       '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM70 -word_size 2',    '10' ],
            [ 50,  100,      '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix BLOSUM80 -word_size 2', '10' ],
            [ 100, 10000000, '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix BLOSUM62 -word_size 3', '10' ],
        ],

        # more stringent clustering params than defaults
        'other_clustering_options' => '-w 0 -s 0.75 -b 0.1 -O -C',

        'goc_taxlevels' => ['Coronaviridae'],
        'do_goc'        => 1,

        'use_raxml'              => 1,
        'do_jaccard_index'       => 0,
        'do_cafe'                => 0,
        'do_gene_qc'             => 0,
        'do_homology_stats'      => 1,
        'do_homology_id_mapping' => 0,
    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Here we adjust the resource class of some analyses to the Pan division
    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'HMMer_classifyPantherScore'    => '2Gb_job',
        'hcluster_run'                  => '1Gb_job',
        'hcluster_parse_output'         => '2Gb_job',
        # Many decision-type analyses take more memory for Pan. Because of the fatter Registry ?
        'tree_building_entry_point'     => '500Mb_job',
        'treebest_decision'             => '500Mb_job',
        'hc_post_tree'                  => '500Mb_job',
        'ortho_tree_decision'           => '500Mb_job',
        'hc_tree_homologies'            => '500Mb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }

    # allow_subtaxa
    $analyses_by_name->{'make_treebest_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;

    # due to v high sequence similarity, cdhit removes all members for some species
    # so we need to skip empty files in a few analyses
    # $analyses_by_name->{'make_blastdb'}->{'-parameters'}->{'allow_empty_files'} = 1;
    # $analyses_by_name->{'members_against_allspecies_factory'}->{'-parameters'}->{'allow_empty_files'} = 1;
    # $analyses_by_name->{'members_against_nonreusedspecies_factory'}->{'-parameters'}->{'allow_empty_files'} = 1;
}


1;
