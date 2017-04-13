=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Compara::PipeConfig::EBI::EnsemblProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.


=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EnsemblProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details

    # parameters that are likely to change from execution to another:
        # You can add a letter to distinguish this run from other runs on the same release

        'test_mode' => 1, #set this to 0 if this is production run
        
        'rel_suffix'            => '',
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

    # custom pipeline name, in case you don't like the default one
        # 'rel_with_suffix' is the concatenation of 'ensembl_release' and 'rel_suffix'
        'pipeline_name'         => 'protein_trees_'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => 'ensembl',

    #default parameters for the geneset qc


    # dependent parameters: updating 'base_dir' should be enough
        'base_dir'              => '/hps/nobackup/production/ensembl/'.$self->o('ENV', 'USER').'/',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,

    # blast parameters:

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => { 'saccharomyces_cerevisiae' => 2 },
        # File with gene / peptide names that must be excluded from the clusters (e.g. know to disturb the trees)
        'gene_blacklist_file'           => '/nfs/production/panda/ensembl/warehouse/compara/proteintree_blacklist.e82.txt',

    # tree building parameters:
        'use_quick_tree_break'      => 0,
        'use_notung'                => 0,

    # alignment filtering options

    # species tree reconciliation

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],
        # affects 'group_genomes_under_taxa'
        'filter_high_coverage'      => 1,

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',

    # executable locations:

    # HMM specific parameters (set to 0 or undef if not in use)
       # The location of the HMM library.
        'hmm_library_basedir'       => '/hps/nobackup/production/ensembl/compara_ensembl/treefam_hmms/2015-12-18',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 1500,
        'blastpu_capacity'          => 150,
        'mcoffee_capacity'          => 600,
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
        'ortho_tree_capacity'       => 250,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'other_paralogs_capacity'   => 150,
        'homology_dNdS_capacity'    => 300,
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
        'store_goc_capacity'        => 70,
	      'genesetQC_capacity'        => 100,

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        'host'  => 'mysql-treefam-prod.ebi.ac.uk',
        'port'  => 4401,

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@mysql-e-farm-test56.ebi.ac.uk:4449/muffato_compara_master_20140317',
        'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',

        # Ensembl-specific databases
        'staging_loc' => {                     # general location of half of the current release core databases
            -host   => 'mysql-ens-sta-1',
            -port   => 4519,
            -user   => 'ensro',
            -pass   => '',
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-ensembl-mirror.ebi.ac.uk',
            -port   => 4240,
            -user   => 'anonymous',
            -pass   => '',
            -db_version => Bio::EnsEMBL::ApiVersion::software_version()-1,
        },

        'egmirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-eg-mirror.ebi.ac.uk',
            -port   => 4157,
            -user   => 'ensro',
            -pass   => '',
        },

        'triticum_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-cluster-eg-prod-1.ebi.ac.uk',
            -port   => 4238,
            -user   => 'ensro',
            -pass   => '',
        },

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ $self->o('staging_loc')],

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('livemirror_loc') ],

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        'prev_rel_db' => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',

        # If 'prev_rel_db' above is not set, you need to set all the dbs individually
        #'reuse_db'              => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',
        #'mapping_db'            => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',


        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
        'clustering_mode'           => 'blastp',

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   'members' means that only the members are copied over, and the rest will be re-computed
        #   'hmms' is like 'members', but also copies the HMM profiles. It requires that the clustering mode is not 'blastp'  >> UNIMPLEMENTED <<
        #   'hmm_hits' is like 'hmms', but also copies the HMM hits  >> UNIMPLEMENTED <<
        #   'blastp' is like 'members', but also copies the blastp hits. It requires that the clustering mode is 'blastp'
        #   'clusters' is like 'hmm_hits' or 'blastp' (depending on the clustering mode), but also copies the clusters
        #   'alignments' is like 'clusters', but also copies the alignments  >> UNIMPLEMENTED <<
        #   'trees' is like 'alignments', but also copies the trees  >> UNIMPLEMENTED <<
        #   'homologies is like 'trees', but also copies the homologies  >> UNIMPLEMENTED <<

    # CAFE parameters
        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => 1,
        'use_timetree_times'        => 1,

    # GOC parameters
        'goc_taxlevels'                 => ["Euteleostomi","Ciona"],

    # Extra analyses
        # Export HMMs ?
        'do_hmm_export'                 => 1,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'                    => 1,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'             => 1,
        # Do we need a mapping between homology_ids of this database to another database ?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping'                 => 1,
    };
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    my %overriden_rc_names = (
        'CAFE_table'                => '24Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
    $analyses_by_name->{'CAFE_analysis'}->{'-parameters'}{'pvalue_lim'} = 1;
}


1;

