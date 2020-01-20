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

Bio::EnsEMBL::Compara::PipeConfig::Pan::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Pan::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id <curr_ptree_mlss_id>

=head1 DESCRIPTION

The Pan PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Pan::ProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    'division'   => 'pan',

    # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
    # values were infered by checking previous releases, values that are out of these ranges may be caused by assembly and/or gene annotation problems.
        'mapped_gene_ratio_per_taxon' => {
            '2759'    => 0.5,     #eukaryotes
            '33090'   => 0.65,    #plants
            '3193'    => 0.7,     #land plants
            '3041'    => 0.65,    #green algae
            '3027'    => 0.4,     #cryptomonads
            '2611341' => 0.4,     #Metamonada
        },

    # plots
        #compute Jaccard Index and Gini coefficient (Lorenz curve)
        'do_jaccard_index'          => 0,

    # CAFE parameters
        # Do we want to initialise the CAFE part now ?
        'do_cafe'                  => 0,

    # Extra analyses
        # Do we want the Gene QC part to run ?
        'do_gene_qc'             => 0,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'      => 0,
        # Do we need a mapping between homology_ids of this database to another database ?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping' => 0,
    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Here we adjust the resource class of some analyses to the Pan division
    $analyses_by_name->{'hcluster_run'}->{'-rc_name'} = '1Gb_job';
    $analyses_by_name->{'hcluster_parse_output'}->{'-rc_name'} = '2Gb_job';
    $analyses_by_name->{'tree_building_entry_point'}->{'-rc_name'} = '500Mb_job';
    $analyses_by_name->{'HMMer_classifyPantherScore'}->{'-rc_name'} = '2Gb_job';
}


1;
