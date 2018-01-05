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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Example::TFProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::TFProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

The PipeConfig example file for Treefam's version of ProteinTrees pipeline.

=head1 CONTACT

Please contact Compara or TreeFam with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::TFProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details

    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        #mlss_id => 40043,
        'treefam_release'               => 10,
        'rel_suffix'        => '', # set it to '' for the actual release
        'rel_with_suffix'       => $self->o('treefam_release').$self->o('rel_suffix'),

    # custom pipeline name, in case you don't like the default one
		#'pipeline_name'         => $self->o('division').$self->o('rel_with_suffix').'_hom_eg'.$self->o('eg_release').'_e'.$self->o('ensembl_release'),
		#'pipeline_name'         => 'treefam_10_mammals_baboon',
		#'pipeline_name'         => 'ckong_protein_trees_compara_homology_protists_topup24',
		'pipeline_name'         => 'TreeFam10',
        # Tag attached to every single tree
        'division'              => 'treefam',

    # dependent parameters: updating 'work_dir' should be enough

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,

    # blast parameters:

    # clustering parameters:

    # tree building parameters:
        'use_quick_tree_break'      => 0,
        'use_raxml'                 => 1,
        'use_notung'                => 1,
        'do_model_selection'        => 0,

    # sequence type used on the phylogenetic inferences
    # It has to be set to 1 for the strains
        'use_dna_for_phylogeny'     => 0,
        #'use_dna_for_phylogeny'     => 1,

    # alignment filtering options

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
        'species_tree_input_file'   => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.treefam.topology.nw',
        # you can define your own species_tree for 'notung'. It *has* to be binary

    # homology_dnds parameters:

    # mapping parameters:

    # executable locations:
        # TODO: this one has to be installed in the Cellar
        'pantherScore_path'         => '/nfs/production/xfam/treefam/software/pantherScore1.03/',

    # HMM specific parameters (set to 0 or undef if not in use)
       # The location of the HMM library. If the directory is empty, it will be populated with the HMMs found in 'panther_like_databases' and 'multihmm_files'
       'hmm_library_basedir'     => '/hps/nobackup/production/ensembl/compara_ensembl/treefam_hmms/2015-12-18',

       # Dumps coming from InterPro
       'panther_annotation_file'    => '/dev/null',
       #'panther_annotation_file' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_dummy.txt',

       # A file that holds additional tags we want to add to the HMM clusters (for instance: Best-fit models)
        'extra_model_tags_file'     => undef,

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>  10,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'blastpu_capacity'          => 150,
        'mcoffee_capacity'          => 200,
        'split_genes_capacity'      => 400,
        'alignment_filtering_capacity'  => 200,
        'cluster_tagging_capacity'  => 200,
        'loadtags_capacity'         => 200,
        'prottest_capacity'         => 200,
        'treebest_capacity'         => 500,
        'raxml_capacity'            => 200,
        'copy_tree_capacity'        => 100,
        'examl_capacity'            => 400,
        'notung_capacity'           => 100,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 100,
        'ktreedist_capacity'        => 150,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 400,
		'HMMer_classifyPantherScore_capacity'=> 1000,
        'loadmembers_capacity'      => 30,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'raxml_update_capacity'     => 1000,
        'ortho_stats_capacity'      => 10,
        'goc_capacity'              => 30,
        'genesetQC_capacity'        => 100,

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',
		#'master_db' => 'mysql://admin:XXXXXXXX@mysql-treefam-prod:4401/treefam_master10',

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    pipeline_db => {
      -host   => 'mysql-treefam-prod',
      -port   => 4401,
      -user   => 'admin',
      -pass   => $self->o('password'),
	  #-dbname => 'TreeFam'.$self->o('release').$self->o('release_suffix'),
	  #-dbname => 'treefam_10_mammals_baboon',
	  #-dbname => 'ckong_protein_trees_compara_homology_protists_topup24',
	  -dbname => 'TreeFam10',
	  -driver => 'mysql',
      #-db_version => $self->o('ensembl_release')
    },
    eg_mirror => {       
            -host => 'mysql-eg-mirror.ebi.ac.uk',
            -port => 4157,
            -user => 'ensro',
			#-verbose => 1,
			-db_version => 83,
   },
    ensembl_mirror => {
            -host => 'mysql-ensembl-mirror.ebi.ac.uk',
            -user => 'anonymous',
            -port => '4240',
			#-verbose => 1,
			-db_version => 83,
    },
	master_db=> {
            -host => 'mysql-treefam-prod',
            -user => 'admin',
            -port => '4401',
			-pass => $self->o('password'),
            #-verbose => 1,
            #-dbname => 'treefam_master10',
            -dbname => 'treefam_master',
	  		-driver => 'mysql',
			#-db_version => 75
    },

	#Used to fetch:
		#triticum_aestivum_a
		#triticum_aestivum_b
		#triticum_aestivum_d
	eg_prod=> {
            -host => 'mysql-eg-prod-1.ebi.ac.uk',
            -port => 4238,
            -user => 'ensro',
			#-verbose => 1,
			-db_version => 30,
   },

    #ncbi_eg=> {
            #-host => 'mysql-eg-mirror.ebi.ac.uk',
            #-user => 'anonymous',
            #-port => '4157',
            #-verbose => 1,
      		#-dbname => 'ensembl_compara_plants_22_75',
	  		#-driver => 'mysql',
			#-db_version => 75
    #},

    #staging_1 => {
    #  -host   => 'mysql-eg-staging-1.ebi.ac.uk',
    #  -port   => 4160,
    #  -user   => 'ensro',
    #  -db_version => $self->o('ensembl_release')
    #},

    #staging_2 => {
    #  -host   => 'mysql-eg-staging-2.ebi.ac.uk',
    #  -port   => 4275,
    #  -user   => 'ensro',
    #  -db_version => $self->o('ensembl_release')
    #},

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs' => [ $self->o('master_db'), $self->o('eg_mirror'), $self->o('ensembl_mirror'), $self->o('eg_prod') ],
        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('master_db'), $self->o('eg_mirror'), $self->o('ensembl_mirror'), $self->o('eg_prod') ],

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        #'prev_rel_db' => 'mysql://ensro@mysql-eg-staging-1.ebi.ac.uk:4160/ensembl_compara_fungi_19_72',
        #'prev_rel_db' => 'mysql://treefam_ro:treefam_ro@mysql-treefam-prod:4401/TreeFam10_final_filtering_other_notung_param',
        #'prev_rel_db' => 'mysql://admin:'.$self->o('password').'@mysql-treefam-prod:4401/TreeFam10_final_filtering_other_notung_param',

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
		'clustering_mode'           => 'hybrid',
		#'clustering_mode'           => 'hmm',
		#'clustering_mode'           => 'topup',

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
        'initialise_cafe_pipeline'  => undef,

    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'mcoffee'                   => '8Gb_job',
        'mcoffee_himem'             => '64Gb_job',
        'mafft'                     => '8Gb_job',
        'mafft_himem'               => '32Gb_job',
        'split_genes'               => '2Gb_job',
        'split_genes_himem'         => '8Gb_job',
        'trimal'                    => '4Gb_job',
        'notung'                    => '4Gb_job',
        'notung_himem'              => '32Gb_job',
        'ortho_tree'                => '2Gb_job',
        'ortho_tree_himem'          => '32Gb_job',
        'ortho_tree_annot'          => '2Gb_job',
        'ortho_tree_annot_himem'    => '32Gb_job',
        'build_HMM_aa'              => '500Mb_job',
        'build_HMM_aa_himem'        => '2Gb_job',
        'build_HMM_cds'             => '1Gb_job',
        'build_HMM_cds_himem'       => '4Gb_job',
        'raxml_epa_longbranches_himem'  => '16Gb_job',
		'make_blastdb_unannotated'  => '4Gb_job',
	    'unannotated_all_vs_all_factory' => '4Gb_job',
	    'blastp_unannotated'        => '4Gb_job',
	    'hcluster_dump_input_all_pafs'  => '4Gb_job',
	    'hcluster_parse_output'     => '4Gb_job',
	    'cluster_factory'           => '4Gb_job',
	    'treebest_small_families'   => '4Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }

    # Other parameters that have to be set
    $analyses_by_name->{'notung'}->{'-parameters'}{'notung_memory'} = 3500;
    $analyses_by_name->{'notung_himem'}->{'-parameters'}{'notung_memory'} = 29000;
    $analyses_by_name->{'prottest'}->{'-parameters'}{'prottest_memory'} = 3500;
    $analyses_by_name->{'prottest'}->{'-parameters'}{'n_cores'} = 16;
    $analyses_by_name->{'prottest_himem'}->{'-parameters'}{'prottest_memory'} = 14500;
    $analyses_by_name->{'prottest_himem'}->{'-parameters'}{'n_cores'} = 16;
    $analyses_by_name->{'prottest'}->{'-parameters'}{'cmd_max_runtime'} = 518400;
    $analyses_by_name->{'prottest_himem'}->{'-parameters'}{'cmd_max_runtime'} = 518400;
    $analyses_by_name->{'mcoffee'}->{'-parameters'}{'cmd_max_runtime'} = 129600;
    $analyses_by_name->{'mcoffee_himem'}->{'-parameters'}{'cmd_max_runtime'} = 129600;
    $analyses_by_name->{'ortho_tree'}->{'-parameters'}{'store_homologies'} = 0;
    $analyses_by_name->{'ortho_tree'}->{'-parameters'}{'input_clusterset_id'} = 'notung';
    $analyses_by_name->{'ortho_tree_himem'}->{'-parameters'}{'store_homologies'} = 0;

    #ExaML running times
    foreach my $logic_name (keys %{$analyses_by_name}) {
        if ( ($logic_name =~ /examl_/) || ($logic_name =~ /raxml_\d/) ){
            #   Setup running time to 6 days, then dataflows into branch -2
            #   himem analysis are not dataflowing to -2, they should dataflow to the himem of the corresponding next analysis
            $analyses_by_name->{$logic_name}->{'-parameters'}{'cmd_max_runtime'} = 518400;
        }
    }

}


1;

