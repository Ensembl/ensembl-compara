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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Example::QfoBlastProteinTrees_conf

=head1 DESCRIPTION  

Parameters to run the ProteinTrees pipeline on the Quest-for-Orthologs dataset using
a all-vs-all blast clustering

=head1 CONTACT

Please contact Compara with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::QfoBlastProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Sanger::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the Ensembl ones

    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        'mlss_id'   => undef,

    # custom pipeline name, in case you don't like the default one
        'pipeline_name'         => 'qfo_201104_e'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => 'qfo',

    # "Member" parameters:
        'allow_missing_coordinates' => 1,
        'allow_missing_cds_seqs'    => 1,

    # blast parameters:

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                 => { },

    # species tree reconciliation
        'species_tree_input_file'   => '/nfs/users/nfs_m/mm14/workspace/src/qfo/ensembl-compara/scripts/pipeline/species_tree.qfo_2015.nw',

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => [ ],

    # mapping parameters:
        'do_stable_id_mapping'      => 0,
        'do_treefam_xref'           => 0,

    # executable locations:
        'treebest_exe'              => '/nfs/users/nfs_m/mm14/workspace/treebest/treebest.qfo',

    # connection parameters to various databases:

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => undef,
        'ncbi_db'   => 'mysql://ensro@compara1:3306/mm14_ensembl_compara_master',

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ ],
        'curr_file_sources_locs'    => [ '/nfs/users/nfs_m/mm14/workspace/src/qfo/ensembl-compara/qfo.json' ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ ],

        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => 0,

    };
}


sub tweak_analyses {
    my $self = shift;
    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    foreach my $logic_name (qw(treebest treebest_short treebest_long_himem)) {
        $analyses_by_name->{$logic_name}->{'-parameters'}{'cdna'} = 0;
        $analyses_by_name->{$logic_name}->{'-parameters'}{'store_intermediate_trees'} = 0;
        $analyses_by_name->{$logic_name}->{'-parameters'}{'store_filtered_align'} = 0;
        $analyses_by_name->{$logic_name}->{'-parameters'}{'store_tree_support'} = 0;
    }
    $analyses_by_name->{'cluster_factory'}->{'-rc_name'} = '500Mb_job';
}


1;

