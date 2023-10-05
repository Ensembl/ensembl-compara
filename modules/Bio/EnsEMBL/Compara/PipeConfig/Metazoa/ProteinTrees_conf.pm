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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Metazoa PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'   => 'metazoa',

        # homology_dnds parameters:
        'taxlevels' => ['Drosophila' ,'Hymenoptera', 'Nematoda'],

        # GOC parameters:
        'goc_taxlevels' => ['Decapoda', 'Daphnia', 'Thoracicalcarea', 'Neoptera', 'Mollusca', 'Deuterostomia', 'Anthozoa'],

        # HighConfidenceOrthologs parameters:
        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Anthozoa', 'Apinae', 'Asteroidea', 'Daphnia', 'Echinozoa', 'Haliotis', 'Penaeus', 'Scleractinia', 'Thoracicalcarea' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'Decapoda', 'Deuterostomia', 'Mollusca', 'Neoptera' ],
                'thresholds'    => [ 25, 25, 25 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],
        
        # Extra analyses:
        # Gain/loss analysis?
        'do_cafe'                => 0,
        # Compute dNdS for homologies?
        'do_dnds'                => 1,
        # Do we want the Gene QC part to run?
        'do_gene_qc'             => 0,
        # Do we need a mapping between homology_ids of this database to another database?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping' => 0,

        # hive_capacity values for some analyses:
        'blastp_capacity'           => 420,
        'blastpu_capacity'          => 100,
        'split_genes_capacity'      => 200,
        'cluster_tagging_capacity'  => 200,
        'homology_dNdS_capacity'    => 200,
        'treebest_capacity'         => 200,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'goc_capacity'              => 200,
        'goc_stats_capacity'        =>  15,
        'other_paralogs_capacity'   => 100,
        'mcoffee_short_capacity'    => 200,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,
    };
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    # Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'mcoffee'           => '8Gb_job',
        'mcoffee_himem'     => '32Gb_job',
        'mafft'             => '8Gb_2c_job',
        'mafft_himem'       => '32Gb_4c_job',
        'treebest'          => '4Gb_job',
        'members_against_allspecies_factory'        => '2Gb_job',
        'members_against_nonreusedspecies_factory'  => '2Gb_job',
    );

    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}


1;
