=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

    # Pan division doesn't run any type of alignment
    'orth_wga_complete' => 1,

    # plots
        #compute Jaccard Index and Gini coefficient (Lorenz curve)
        'do_jaccard_index'          => 0,

    # Extra analyses
        # gain/loss analysis ?
        'do_cafe'                => 0,
        # gene order conservation ?
        'do_goc'                 => 0,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'             => 0,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'      => 1,
        # Do we need a mapping between homology_ids of this database to another database ?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping' => 0,

        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Apes', 'Murinae' ],
                'thresholds'    => [ undef, undef, 80 ],
            },
            {
                'taxa'          => [ 'Mammalia', 'Aves', 'Percomorpha' ],
                'thresholds'    => [ undef, undef, 50 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],
    };
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    # Pan division doesn't run any type of alignment
    my $attrib_files = {'high_conf' => '#high_conf_file#'};
    $attrib_files->{'goc'} = '#goc_file#' if $self->o('do_goc');
    $analyses_by_name->{import_homology_table}->{'-parameters'}->{'attrib_files'} = $attrib_files;

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
        'copy_dumps_to_shared_loc'      => '500Mb_job',
        'homology_dumps_mlss_id_factory'    => '500Mb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}


1;
