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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf

=head1 DESCRIPTION

    Shared configuration options for ProteinTrees pipeline at the EBI


=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # the master database for synchronization of various ids (use undef if you don't have a master database)
    'master_db' => 'compara_master',
    'member_db' => 'compara_members',

    # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
    'prev_rel_db' => 'compara_prev',

    # Points to the previous protein trees production database. Will be used for various GOC operations. 
    # Use "undef" if running the pipeline without reuse.
    'goc_reuse_db' => 'ptrees_prev',

    # non-standard executable locations
        'treerecs_exe'              => '/homes/mateus/reconcile/Treerecs/bin/Treerecs',

        # HMM specific parameters
        'hmm_library_name'              => 'compara_hmm_91.hmm3',
        'hmmer_search_cutoff'           => '1e-23',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 1500,
        'blastpu_capacity'          => 150,
        'mcoffee_short_capacity'    => 600,
        'mafft_capacity'            => 2500,
        'mafft_himem_capacity'      => 1200,
        'split_genes_capacity'      => 600,
        'alignment_filtering_capacity'  => 200,
        'cluster_tagging_capacity'  => 100,
        'loadtags_capacity'         => 200,
        'prottest_capacity'         => 200,
        'treebest_capacity'         => 400,
        'raxml_capacity'            => 200,
        'examl_capacity'            => 400,
        'notung_capacity'           => 200,
        'copy_tree_capacity'        => 100,
        'ortho_tree_capacity'       => 50,
        'quick_tree_break_capacity' => 1500,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'other_paralogs_capacity'   => 50,
        'homology_dNdS_capacity'    => 1300,
        'hc_capacity'               => 150,
        'decision_capacity'         => 150,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 400,
        'loadmembers_capacity'      =>  30,
        'HMMer_classifyPantherScore_capacity'   => 1000,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'raxml_update_capacity'     => 50,
        'ortho_stats_capacity'      => 10,
        'goc_capacity'              => 30,
        'goc_stats_capacity'        => 70,
        'genesetQC_capacity'        => 100,
        'cafe_capacity'             => 50,

    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded
    };
}

1;

