=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Compara::PipeConfig::ProteinTreesHybrid_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut
package Bio::EnsEMBL::Compara::PipeConfig::ProteinTreesHybrid_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
      %{$self->SUPER::default_options},   # inherit the generic ones
       'mlss_id'               => 90984, 
       # 131133 eg21 from all divisions e! & eg! except bacteria, to build panHMM profiles
       # 131134 eg21 from all divisions e! & eg! WITH bacteria, to build panHMM profiles
       # 94443 eg22, 90984 eg21 protists
       # 91325 eg21 fungi
       # 93630 eg22, 92367 eg21 metazoa
       # 93131 eg22, 92429 eg21 plants
       'ensembl_release'       => '75',   # it defaults to Bio::EnsEMBL::ApiVersion::software_version(): you're unlikely to change the value
       'do_not_reuse_list'     => [ ],    # names of species we don't want to reuse this time
       'method_link_dump_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/method_link.txt',
       'pipeline_name' 		   => 'protein_trees_compara_homology_HybridPanther_Protists1_'.$self->o('ensembl_release'),
       'division'			   => '',
       'exe_dir'               =>  '/nfs/panda/ensemblgenomes/production/compara/binaries',
	   'base_dir'              =>  '/nfs/nobackup2/ensemblgenomes/ckong/workspace/'.$self->o('ENV', 'USER').'/hive',
       'work_dir'              => $self->o('base_dir').'/'.$self->o('mlss_id').'/protein_trees_'.$self->o('pipeline_name'),
       'fasta_dir'             => $self->o('work_dir'). '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp'
       'cluster_dir'           => $self->o('work_dir'). '/cluster',
       'dump_dir'              => $self->o('work_dir'). '/dumps',
	 # For building new profiles
	   'buildprofiles_dir'	   => $self->o('work_dir').'/buildHMMprofiles', 
	   'fasta_file' 		   => $self->o('buildprofiles_dir').'/unclassify_sequence.fa',
       'msa_dir'    		   => $self->o('buildprofiles_dir').'/msa',    
       'hmmLib_dir'    		   => $self->o('buildprofiles_dir').'/hmmLib',
       'hmm_profiles_type1'    => 'panther9.0_treefam', # to tag profiles stored hmm_profile table
       'hmm_profiles_type2'    => 'new_profiles',       # 'new_profiles' is hardcode in PantherLoadModels.pm 
     # "Member" parameters:
       'allow_ambiguity_codes' => 0,
       'allow_pyrrolysine'     => 0,
     # blast parameters:
       'blast_params'          => '-seg no -max_hsps_per_subject 1 -use_sw_tback -num_threads 1',
       'blast_options'  	   => '-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1', # used for BuildHMMprofiles::BlastpWithFasta
       'blast_tmp_dir'         => '/tmp',  # if empty, will use Blast Analysis' default
       'protein_members_range' => 100000000, # highest member_id for a protein member
     # clustering parameters:
       'outgroups'                     => {127},      # affects 'hcluster_dump_input_per_genome'
       'clustering_max_gene_halfcount' => 750,     # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'
     # tree building parameters:
       'treebreak_gene_count'      => 400,     # affects msa_chooser
       'mafft_gene_count'          => 200,     # affects msa_chooser
       'mafft_runtime'             => 7200,    # affects msa_chooser
       'species_tree_input_file'   => '',      # you can define your own species_tree for 'njtree_phyml' and 'ortho_tree'
     # homology_dnds parameters:
       'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/protein_trees.codeml.ctl.hash',      # used by 'homology_dNdS'
       'taxlevels'                 => [],
       'filter_high_coverage'      => 0,   # affects 'group_genomes_under_taxa'
     # mapping parameters:
       'do_stable_id_mapping'      => 1,
       'do_treefam_xref'           => 0,
       'tf_release'                => '9_69',     # The TreeFam release to map to
     # executable locations:
	   'hcluster_exe'    =>  $self->o('exe_dir').'/hcluster_sg',
	   'mcoffee_home'	 =>  '/nfs/panda/ensemblgenomes/external/t-coffee',
	   'mafft_home'      =>  $self->o('exe_dir').'/mafft-distro',
	   'sreformat_exe'   =>  $self->o('exe_dir').'/sreformat',
	   'treebest_exe'    =>  $self->o('exe_dir').'/treebest',
       'quicktree_exe'   =>  $self->o('exe_dir').'/quicktree',
       'buildhmm_exe'    =>  $self->o('exe_dir').'/hmmbuild',
       'hmmemit_exe'     =>  $self->o('exe_dir').'/hmmemit',
       'codeml_exe'      =>  $self->o('exe_dir').'/codeml',
       'ktreedist_exe'   =>  $self->o('exe_dir').'/ktreedist',
       'blast_bin_dir'   => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2.2.27+/bin',
	   'wublastp_exe'	 =>  $self->o('exe_dir').'/wublast/blastp',
	   'xdformat_exe'	 =>  $self->o('exe_dir').'/wublast/xdformat',
	   ## For building new profiles	    
  	   'hmmbuild_exe'    =>  $self->o('exe_dir').'/hmmbuild_2', # for HMMer2 to use with PantherScore.pl  else hmmbuild => HMMer3
	   'hmmcalibrate'    =>  $self->o('exe_dir').'/hmmcalibrate',
    # HMM specific parameters (set to 0 or undef if not in use)
       'hmm_clustering'       => 1, ## by default run hmm clustering
       'hmm_buildhmmprofiles' => 0, ## by default do not create new profiles
       ## This should point to PANTHER9.0+TreeFAM profiles if you are building new profiles OR
       ##             point to PanHMM profiles (PANTHER9.0+TreeFAM+New promoted profiles) if you are NOT building new profiles
       #'cm_file_or_directory' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/PROTISTS_HMM2_EG20_8_1_PTHR_SF/hmmLib/', 
       #'hmm_library_basedir'  => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/PROTISTS_HMM2_EG20_8_1_PTHR_SF/hmmLib/', 
       'cm_file_or_directory' => '/nfs/nobackup2/xfam/treefam/datasets/panhmms/panhmm9', 
       'hmm_library_basedir'  => '/nfs/nobackup2/xfam/treefam/datasets/panhmms/panhmm9', 
       'pantherScore_path'    => '/nfs/panda/ensemblgenomes/data/pantherScore1.03',
       'hmmer_path'           => '/nfs/panda/ensemblgenomes/external/hmmer-2/binaries',
	   ## Point to dummy file 'panther_Interpro_annot_v8_1/loose_dummy.txt' in case there is NO interpro annotation available
       'panther_annotation_PTHR' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_dummy.txt',
       'panther_annotation_SF'   => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_dummy.txt',
       #'panther_annotation_PTHR' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_EG_HUMAN_PTHR.txt',
       #'panther_annotation_SF'   => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_EG_HUMAN_SF.txt',
    # hive_capacity values for some analyses:
       'reuse_capacity'            =>   4,
       'blast_factory_capacity'    =>  50,
       'mcoffee_capacity'          => 600,
       'split_genes_capacity'      => 600,
       'njtree_phyml_capacity'     => 400,
       'ortho_tree_capacity'       => 200,
       'ortho_tree_annot_capacity' => 300,
       'quick_tree_break_capacity' => 100,
       'build_hmm_capacity'        => 200,
       'ktreedist_capacity'        =>  50,
       'merge_supertrees_capacity' => 100,
       'other_paralogs_capacity'   => 100,
       'homology_dNdS_capacity'    => 200,
       'qc_capacity'               =>   4,
       'HMMer_classify_capacity'   => 400,
       'hc_capacity'   			=>   4,
		## For building new profiles
       'blastp_capacity'           => 400,        
       'hmmbuild_capacity'	   		=> 100,
       'hmmcalibrate_capacity' 	=> 100,
    # hive priority for non-LOCAL health_check analysis:
       'hc_priority'               => -10,
    # connection parameters to various databases:
        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        #'host' => 'compara1',
        # the master database for synchronization of various ids (use undef if you don't have a master database)
       'master_db' => {     # the master database for synchronization of various ids
            -host   => 'mysql-eg-devel-2.ebi.ac.uk',
		    -port   => 4207,
			-user   => 'ensrw',
		    -pass   => 'scr1b3d2',
		    -dbname => 'ensembl_compara_master',
       },
       #'master_db' => undef,
       'ncbi_db'   => $self->o('master_db'),

       'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
				-host => 'mysql-eg-mirror.ebi.ac.uk',
				-port => 4205,
				-user => 'ensrw',
		    	-pass => 'writ3r',
       },

       'livemirror_loc_2' => {                   # general location of the previous release core databases (for checking their reusability)
				-host => 'ensembldb.ensembl.org',
				-port => 5306,
				-user => 'anonymous',
       },
       # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
       # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
       'curr_core_sources_locs'    => [ $self->o('livemirror_loc'),$self->o('livemirror_loc_2') ],
	   'curr_core_registry'        => '/homes/ckong/work/tasks/EG-174_ComparaHMM/registry.mysql-eg-mirror.ebi.ac.uk.pm',
#       'curr_core_registry'        => undef,
       'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

       # Add the database entries for the core databases of the previous release
       'prev_core_sources_locs'	=> [ $self->o('livemirror_loc') ],
        
       # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
       'prev_rel_db' 				 	=> #undef,
       {   # usually previous release database on compara1
				-host => 'mysql-eg-mirror.ebi.ac.uk',
				-port => 4205,
				-user => 'ensrw',
		    	-pass => 'writ3r',
             	-dbname => 'ensembl_compara_protists_20_73',
       },

        # Force a full re-run of blastp
       'force_blast_run'           => 0,
    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    # There must be some species on which to compute trees
    die "There must be some species on which to compute trees"
        if ref $self->o('curr_core_sources_locs') and not scalar(@{$self->o('curr_core_sources_locs')})
        and ref $self->o('curr_file_sources_locs') and not scalar(@{$self->o('curr_file_sources_locs')})
        and not $self->o('curr_core_registry');

    # The master db must be defined to allow mapping stable_ids and checking species for reuse
    die "The master dabase must be defined with a mlss_id" if $self->o('master_db') and not $self->o('mlss_id');
    die "mlss_id can not be defined in the absence of a master dabase" if $self->o('mlss_id') and not $self->o('master_db');
    die "Mapping of stable_id is only possible with a master database" if $self->o('do_stable_id_mapping') and not $self->o('master_db');
    die "Species reuse is only possible with a master database" if $self->o('prev_rel_db') and not $self->o('master_db');
    die "Species reuse is only possible with some previous core databases" if $self->o('prev_rel_db') and ref $self->o('prev_core_sources_locs') and not scalar(@{$self->o('prev_core_sources_locs')});

    # Without a master database, we must provide other parameters
    die if not $self->o('master_db') and not $self->o('ncbi_db');

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        'mkdir -p '.$self->o('cluster_dir'),
        'mkdir -p '.$self->o('dump_dir'),
        'mkdir -p '.$self->o('fasta_dir'),
        'mkdir -p '.$self->o('buildprofiles_dir'),
        'mkdir -p '.$self->o('hmmLib_dir'),
       
        # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('fasta_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('fasta_dir').' -c -1 || echo "Striping is not available on this system" ',
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
            %{$self->SUPER::pipeline_wide_parameters},
            'hc_member_type'  => 'ENSEMBLPEP',
           };
}


sub pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
    );

    return [
# ---------------------------------------------[backbone]--------------------------------------------------------------------------------

        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ {
                'output_file'   => $self->o('dump_dir').'/#filename#',
            } ],
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'backbone_fire_genome_load' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'backbone_fire_genome_load',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'        => '',
                'filename'          => 'snapshot_1_before_genome_load.sql',
            },
            -flow_into  => {
                '1->A'  => [ 'genome_reuse_factory' ],
                'A->1'  => [ $self->o('hmm_clustering') ? 'backbone_fire_hmmClassify' : 'backbone_fire_allvsallblast' ],
            },
        },

       $self->o('hmm_clustering') ? (
            {
             -logic_name => 'backbone_fire_hmmClassify',
             -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
             -parameters => {
                             'table_list' => '',
                             'filename'       => 'snapshot_2_before_hmmClassify.sql',
                            },
            -flow_into  => {
                            '1->A' => [ 'load_models' ],
                            'A->1' => [ 'backbone_fire_tree_building' ],
                           },
            },
        ) : (), # do not show the hmm analysis if the option is off

### For hmmalign instead of mcoffee
#             {
#              -logic_name => 'backbone_fire_hmmAlign',
#              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
#              -parameters => {
#                              'updated_tables' => 'gene_tree_root gene_tree_root_tag gene_tree_node gene_tree_node_tag gene_tree_node_attr',
#                              'filename'       => 'snapshot_before_hmmalign.sql',
#                              'output_file'    => $self->o('dump_dir') . '/#filename#',
#                             }
#             },

        {   -logic_name => 'backbone_fire_allvsallblast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => '',
                'filename'      => 'snapshot_2_before_allvsallblast.sql',
            },
            -flow_into  => {
                '1->A'  => [ 'blastdb_factory' ],
                'A->1'  => [ 'backbone_fire_hcluster' ],
            },
        },

        {   -logic_name => 'backbone_fire_hcluster',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => '',
                'filename'      => 'snapshot_3_before_hcluster.sql',
            },
            -flow_into  => {
                '1->A'  => [ 'hcluster_dump_factory' ],
                'A->1'  => [ 'backbone_fire_tree_building' ],
            },
        },

        {   -logic_name => 'backbone_fire_tree_building',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'filename'      => 'snapshot_4_before_tree_building.sql',
            },
            -flow_into  => {
                '1->A'  => [ 'large_cluster_factory' ],
                'A->1'  => [ 'backbone_fire_dnds' ],
            },
        },

        {   -logic_name => 'backbone_fire_dnds',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'filename'      => 'snapshot_5_before_dnds.sql',
            },
            -flow_into  => {
                '1->A'  => [ 'group_genomes_under_taxa' ],
                'A->1'  => [ 'backbone_pipeline_finished' ],
            },
        },


        {   -logic_name => 'backbone_pipeline_finished',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -meadow_type    => 'LOCAL',
        },

# ---------------------------------------------[copy tables from master]-----------------------------------------------------------------

        {   -logic_name => 'copy_ncbi_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],
                'column_names' => [ 'table' ],
                'fan_branch_code' => 2,
            },
            -flow_into => {
                '2->A' => [ 'copy_ncbi_table'  ],
                'A->1' => [ 'select_method_links_source' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name    => 'copy_ncbi_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('ncbi_db'),
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'select_method_links_source',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                ($self->o('master_db') ? 1 : 999) => [ 'populate_method_links_from_db' ],
                ($self->o('master_db') ? 999 : 1) => [ 'populate_method_links_from_file' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name    => 'populate_method_links_from_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('master_db'),
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                'table'         => 'method_link',
            },
            -analysis_capacity  => 1,
            -flow_into      => [ 'load_genomedb_factory' ],
            -meadow_type    => 'LOCAL',
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'            => $self->o('master_db'),   # that's where genome_db_ids come from
                'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', ['fetch_by_dbID', $self->o('mlss_id')], 'species_set_obj', 'genome_dbs'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },

                'fan_branch_code'       => 2,
            },
            -flow_into => {
                '2->A' => [ 'load_genomedb' ],
                'A->1' => [ 'create_mlss_ss' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_conf_file'  => $self->o('curr_core_registry'),
                'registry_dbs'        => $self->o('curr_core_sources_locs'),
                'db_version'          => $self->o('ensembl_release'),
                'registry_files'      => $self->o('curr_file_sources_locs'),
            },
            -flow_into  => [ 'check_reusability' ],
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name     => 'populate_method_links_from_file',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'method_link_dump_file' => $self->o('method_link_dump_file'),
                'command_line_db'   => $self->dbconn_2_mysql('pipeline_db', 1),
                'cmd'               => 'mysqlimport #command_line_db# #method_link_dump_file#',
            },
            -flow_into      => [ 'load_all_genomedbs' ],
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'load_all_genomedbs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadAllGenomeDBs',
            -parameters => {
                'registry_conf_file'  => $self->o('curr_core_registry'),
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
            -flow_into => [ 'create_mlss_ss' ],
        },
# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
                'reuse_db'          => $self->o('prev_rel_db'),
                'registry_dbs'      => $self->o('prev_core_sources_locs'),
                'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -hive_capacity => 10,
            -rc_name => '500Mb_job',
            -flow_into => {
                2 => { ':////accu?reused_gdb_ids=[]' => { 'reused_gdb_ids' => '#genome_db_id#'} },
                3 => { ':////accu?nonreused_gdb_ids=[]' => { 'nonreused_gdb_ids' => '#genome_db_id#'} },
            },
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS',
            -parameters => {
                'mlss_id'   => $self->o('mlss_id'),
                'master_db' => $self->o('master_db'),
            },
            -flow_into => [ 'make_species_tree', 'extra_sql_prepare' ],
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name    => 'extra_sql_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [
                    # Non species-set related query. Speeds up the split-genes search
                    'ALTER TABLE member ADD KEY gene_list_index (source_name, taxon_id, chr_name, chr_strand, chr_start)',
                    # Counts the number of species
                    'INSERT INTO meta (meta_key,meta_value) SELECT "species_count", COUNT(*) FROM genome_db',
                ],
            },
            -meadow_type    => 'LOCAL',
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------

        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                               'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                               'for_gene_trees' => 1,
            },
            # -flow_into  => {
            #     3 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
            # },
        },

# ---------------------------------------------[reuse members]-----------------------------------------------------------------------

        {   -logic_name => 'genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #reuse_ss_id#',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                '2->A' => [ 'sequence_table_reuse' ],
                'A->1' => [ 'load_fresh_members_from_db_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('prev_rel_db'),
                            'inputquery' => 'SELECT s.* FROM sequence s JOIN member USING (sequence_id) WHERE sequence_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                            'fan_branch_code' => 2,
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '500Mb_job',
            -flow_into => {
                2 => [ ':////sequence' ],
                1 => [ 'member_table_reuse' ],
            },
        },

        {   -logic_name => 'member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('prev_rel_db'),
                'table'         => 'member',
                'where'         => 'member_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'other_sequence_table_reuse' ],
            },
        },

        {   -logic_name => 'other_sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('prev_rel_db'),
                            'inputquery' => 'SELECT s.member_id, s.seq_type, s.length, s.sequence FROM other_member_sequence s JOIN member USING (member_id) WHERE genome_db_id = #genome_db_id# AND seq_type IN ("cds", "exon_bounded") AND member_id <= '.$self->o('protein_members_range'),
                            'fan_branch_code' => 2,
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '1Gb_job',
            -flow_into => {
                2 => [ ':////other_member_sequence' ],
                1 => [ 'hc_members_per_genome' ],
            },
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode                  => 'members_per_genome',
                hc_member_type        => 'ENSEMBLPEP',
                allow_ambiguity_codes => $self->o('allow_ambiguity_codes'),
            },
            %hc_analysis_params,
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'load_fresh_members_from_db_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #nonreuse_ss_id# AND locator LIKE "Bio::EnsEMBL::DBSQL::DBAdaptor/%"',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                '2->A' => [ 'load_fresh_members_from_db' ],
                '1->A' => [ 'load_fresh_members_from_file_factory' ],
                'A->1' => [ 'hc_members_globally' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'load_fresh_members_from_file_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #nonreuse_ss_id# AND locator NOT LIKE "Bio::EnsEMBL::DBSQL::DBAdaptor/%"',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                2 => [ 'load_fresh_members_from_file' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'load_fresh_members_from_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'store_related_pep_sequences' => 1,
                'allow_pyrrolysine'             => $self->o('allow_pyrrolysine'),
                'find_canonical_translations_for_polymorphic_pseudogene' => 1,
            },
            -rc_name => '2Gb_job',
            -flow_into => [ 'hc_members_per_genome' ],
        },

        {   -logic_name => 'load_fresh_members_from_file',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembersFromFiles',
            -parameters => {
                -need_cds_seq   => 1,
            },
            -rc_name => '2Gb_job',
            -flow_into => [ 'hc_members_per_genome' ],
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_globally',
            },
            %hc_analysis_params,
        },

# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'reusedspecies_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'force_blast_run'   => $self->o('force_blast_run'),
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #reuse_ss_id# AND NOT #force_blast_run#',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                2 => [ 'paf_table_reuse' ],
                1 => [ 'nonreusedspecies_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'nonreusedspecies_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'force_blast_run'   => $self->o('force_blast_run'),
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #nonreuse_ss_id# OR #force_blast_run#',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                2 => [ 'paf_create_empty_table' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('prev_rel_db'),
                'table'         => 'peptide_align_feature_#genome_db_id#',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
            },
            -flow_into  => [ 'members_against_nonreusedspecies_factory' ],
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name => 'paf_create_empty_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'CREATE TABLE IF NOT EXISTS peptide_align_feature_#genome_db_id# LIKE peptide_align_feature',
                            'ALTER TABLE peptide_align_feature_#genome_db_id# DISABLE KEYS, AUTO_INCREMENT=#genome_db_id#00000000',
                ],
            },
            -flow_into  => [ 'members_against_allspecies_factory' ],
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
        },

#----------------------------------------------[classify canonical members based on HMM searches]-----------------------------------
       $self->o('hmm_clustering') ? (
            {
             -logic_name => 'load_models',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PantherLoadModels',
             -parameters => {
                             'pantherScore_path'    => $self->o('pantherScore_path'),
#                             'type'					=> $self->o('hmm_profiles_type1'),
                             'cm_file_or_directory' => $self->o('cm_file_or_directory'),
                             'hmmemit_exe'	   	    => $self->o('hmmemit_exe'),
                            },
             -flow_into  => {
                             '1->A' => [ 'dump_models' ],
                             'A->1' => [ 'buildhmmprofiles_create_tables' ],
                            },
            },

            {
             -logic_name => 'dump_models',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpModels',
             -parameters => {
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmm_library_basedir' => $self->o('hmm_library_basedir'),
                             'blast_bin_dir'       => $self->o('blast_bin_dir'), 
#                             'type'				   => $self->o('hmm_profiles_type1'),
                            },
             },

            {
             -logic_name => 'buildhmmprofiles_create_tables',
             -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
       		 -parameters => {
        			'sql' => [  'CREATE TABLE IF NOT EXISTS sequence_unclassify ( member_id varchar(20) DEFAULT NULL, genome_db_id varchar(20) DEFAULT NULL, cluster_dir_id varchar(20) DEFAULT NULL)',   
        			      	 	'CREATE TABLE IF NOT EXISTS panther_annot_PTHR  ( upi char(13) NOT NULL, ensembl_id char(50) NOT NULL, ensembl_div char(15) NOT NULL, panther_family_id char(15) NOT NULL, start int(11) NOT NULL, end int(11) NOT NULL,  score int(11) NOT NULL, evalue char(25) NOT NULL, PRIMARY KEY (ensembl_id))',        	 			  	 	
        			      	 	'CREATE TABLE IF NOT EXISTS panther_annot_SF    ( upi char(13) NOT NULL, ensembl_id char(50) NOT NULL, ensembl_div char(15) NOT NULL, panther_family_id char(15) NOT NULL, start int(11) NOT NULL, end int(11) NOT NULL,  score int(11) NOT NULL, evalue char(25) NOT NULL, PRIMARY KEY (ensembl_id))',
	        			      	'CREATE TABLE IF NOT EXISTS hmm_annot           ( member_id varchar(20) NOT NULL, model_id char(70) NOT NULL, evalue char(25) NOT NULL)',
        	                  ],     
       			},
             -flow_into  => {
#                             '1' => [ 'HMMer_classifyInterpro' ],
                              '2->A' => [ 'load_PantherAnnotation' ],
							  'A->1' => [ 'HMMer_classifyInterpro'],					 
                           }, 
           },

           {
            -logic_name => 'load_PantherAnnotation',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadAnnotation',
            -parameters => {
                             'panther_annotation_PTHR'  => $self->o('panther_annotation_PTHR'),
                             'panther_annotation_SF'    => $self->o('panther_annotation_SF'),
                           },
             -rc_name => 'default',
            },

           {
            -logic_name => 'HMMer_classifyInterpro',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyInterpro',
            -parameters => {
                             'mlss_id'       => $self->o('mlss_id'),
                             'registry_dbs'  => $self->o('curr_core_sources_locs'),
                            },
            -flow_into  => {
                             '2->A' => [ 'HMMer_classify' ],
							 'A->1' => [ $self->o('hmm_buildhmmprofiles') ? 'prepare_buildhmmprofiles_sequence' :'HMM_clusterize'],					 
                           }, 
             -hive_capacity => $self->o('HMMer_classify_capacity'),
             -rc_name => 'msa_himem',
            },

            {
             -logic_name => 'HMMer_classify',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify',
             -parameters => {
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmm_library_basedir' => $self->o('hmm_library_basedir'),
                             'blast_tmp_dir'	   => $self->o('blast_tmp_dir'), 
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'hmmer_path'          => $self->o('hmmer_path'),
                             'cluster_dir'         => $self->o('cluster_dir'),
                             'store_unclassify'	   => '1',
                            },
             -hive_capacity => $self->o('HMMer_classify_capacity'),
             -rc_name => 'hmmclassify_job',
             -batch_size => 50,
            },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize',
             -parameters => {
                             'cluster_dir'  => $self->o('cluster_dir'),
                             'mlss_id'  	=> $self->o('mlss_id'),
                             'member_type'  => 'protein',
                            },
             -rc_name => '8Gb_job',
             -flow_into => [ 'run_qc_tests' ],
            },

        ) : (), # do not show the hmm analysis if the option is off

# -------------------------------------------------[BuildHMMprofiles pipeline]-------------------------------------------------------
   	  $self->o('hmm_buildhmmprofiles') ? (
   	    { 
    	       -logic_name   => 'prepare_buildhmmprofiles_sequence',
        	   -module       => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::CreateSequence',
        	   -parameters   => {
            		'buildprofiles_dir' => $self->o('buildprofiles_dir'),
           		},
        		-hive_capacity => -1,
        		-flow_into 	   => {
		           	'1->A' => ['CreateBlastDB','paf_create_table'],
            		'A->1' => ['PrepareSequence'],
          		},
   	    },
# ------------------------------------------------[BuildHMMprofiles-> blast step]----------------------------------------------------
      # Creating blastp jobs for each unclassify sequence
	  {  -logic_name => 'PrepareSequence',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::PrepareSequence',
         -parameters => {
	        'fasta_file'       => $self->o('fasta_file'),
            'fan_branch_code'  => 2,
          },
         -flow_into  => {
                '2->A'	 => ['BlastpWithFasta'],
  		  		'A->1' 	 => ['hcluster_factory'],
         },
      },

      { -logic_name => 'CreateBlastDB',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::CreateBlastDB',
        -parameters => {
          'fasta_file'        => $self->o('fasta_file'),
          'xdformat_exe'      => $self->o('xdformat_exe'),
          'buildprofiles_dir' => $self->o('buildprofiles_dir'),
        },
      },

     # Creating peptide_align_feature table to store blast output
     { -logic_name => 'paf_create_table',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
       -parameters => {
        	'sql' => [  'ALTER TABLE `peptide_align_feature` 
        				 MODIFY COLUMN `score` int(5) NOT NULL DEFAULT \'0\' ',
        	         ],     

       },
       -batch_size     =>  100,  # they can be really, really short
       -hive_capacity  => -1,
     },

     # Perform blastp of each sequence against blastDB
	 {   -logic_name => 'BlastpWithFasta',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::BlastpWithFasta',
         -parameters => {
	        'buildprofiles_dir' => $self->o('buildprofiles_dir'), # point to BLASTDB directory
	        'wublastp_exe'	    => $self->o('wublastp_exe'),
	        'blast_options'	    => $self->o('blast_options'),
	        'blast_tmp_dir'	    => $self->o('blast_tmp_dir'),
     	},
        -hive_capacity => $self->o('blastp_capacity'),
        -batch_size    =>  50, 
        -rc_name       => 'default',
    },

# ------------------------------------------------[BuildHMMprofiles-> clustering step]----------------------------------------------------
    {   -logic_name    => 'hcluster_factory',
        -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        -hive_capacity => -1,
        -flow_into 	   => {
           	'1->A' => { 
                   		'hcluster_prepare_input' => [{'ext' => 'txt'}],
               		  },
            'A->1' => [ 'hcluster_run_BuildHMMprofiles' ],
        },
       -wait_for => [ 'BlastpWithFasta' ],
    },

    # Query blast result from peptide_align_feature table in pipeline database: output file => hcluster.txt
    {  -logic_name 	  => 'hcluster_prepare_input',
       -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
       -parameters   => {
           	'cluster_dir'   => $self->o('buildprofiles_dir'),
			'pipeline_name' => $self->o('pipeline_name'),
			'cmd'			=> 'mysql '.$self->dbconn_2_mysql('pipeline_db',0).' '.$self->o('pipeline_db','-dbname').' -e "SELECT qmember_id,hmember_id,score FROM peptide_align_feature" | grep  -v qmember_id > #cluster_dir#/hcluster.#ext#',
        },
        -hive_capacity  => -1,
    },

    # Running hcluster: output file => hcluster.out 
    {   -logic_name	  => 'hcluster_run_BuildHMMprofiles',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
              'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
              'cluster_dir'                   => $self->o('buildprofiles_dir'),
              'hcluster_exe'                  => $self->o('hcluster_exe'),
              'cmd'                           => '#hcluster_exe# -m #clustering_max_gene_halfcount# -w 0 -s 0.34 -O -o #cluster_dir#/hcluster.out #cluster_dir#/hcluster.txt',
         },
        -hive_capacity => -1,
        -flow_into => {
            '1->A'	 => ['HclusterParseOutput'],
  	  		'A->1' 	 => ['cluster_factory_BuildHMMprofiles'],
        },
        -rc_name => '24Gb_job',
    },

    # Parsing hcluster.out file: output file => hcluster_parse.out
    # line 120 next if ($cluster_size < 3) HclusterParseOutput.pm <=> MSA.pm line 84  next if ($cluster_size < 3);
    {   -logic_name  => 'HclusterParseOutput',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HclusterParseOutput',
        -parameters  => {
            'cluster_dir'               => $self->o('buildprofiles_dir'),
        },
        -hive_capacity  => -1,
        -rc_name 		=> '2Gb_job',
        -flow_into 		=> {
            '1'  => {'prepare_cluster_factory_input_ids' => [{'ext' => 'txt'}] },
        },
    },

# ------------------------------------------------[BuildHMMprofiles-> MSA stage]---------------------------------------------
    # Creating file containing list of cluster_ids, output file => cluster_factory_input_ids.txt
    {   -logic_name   => 'prepare_cluster_factory_input_ids',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
            'cluster_dir'   => $self->o('buildprofiles_dir'),
            'cmd'			=> 'cut -f1 #cluster_dir#/hcluster_parse.out | grep -v cluster_id > #cluster_dir#/cluster_factory_input_ids.#ext#',
         },
        -hive_capacity => -1,
        -flow_into 	   => {
            '1'  => {'create_msa_directory'},
        },
    },

    # Create MSA output top directory at the $self->o('buildprofiles_dir'),
    {   -logic_name   => 'create_msa_directory',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
            'buildprofiles_dir' => $self->o('buildprofiles_dir'),
            'cmd'		        => 'mkdir #buildprofiles_dir#/msa',
         },
    },

	# Creating jobs for msa_chooser, 1 job for each cluster_id
  	{   -logic_name => 'cluster_factory_BuildHMMprofiles',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
        -parameters => {
            'inputfile'			=> $self->o('buildprofiles_dir').'/cluster_factory_input_ids.txt',
            'column_names' 		=> ['cluster_id'],
            'fan_branch_code'   => 2,
        },
        -flow_into  => {
			'2->A' 		 =>	['Mafft_BuildHMMprofiles'],
			'A->1' 		 =>	['HmmProfileFactory'],
        },
    },

    {   -logic_name => 'Mafft_BuildHMMprofiles',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::Mafft',
        -parameters => {
            'hcluster_parse'  => $self->o('buildprofiles_dir').'/hcluster_parse.out',
            'fasta_file' 	  => $self->o('fasta_file'),
            'blast_tmp_dir'   => $self->o('blast_tmp_dir'), # To store fasta file of clusters to perform MSA on
            'msa_dir'		  => $self->o('msa_dir'), 
            'mafft_home'      => $self->o('mafft_home'),
        },
        -hive_capacity => $self->o('mcoffee_capacity'),
        -rc_name       => 'msa',
        -priority      => 30,
        -batch_size    => 50, 
        -flow_into     => {
              -1 => [ 'Mafft_himem_BuildHMMprofiles' ],  # MEMLIMIT
        },
    },
        
    {   -logic_name => 'Mafft_himem_BuildHMMprofiles',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::Mafft',
        -parameters => {
            'hcluster_parse'  => $self->o('buildprofiles_dir').'/hcluster_parse.out',
            'fasta_file' 	  => $self->o('fasta_file'),
            'blast_tmp_dir'   => $self->o('blast_tmp_dir'), # To store fasta file of clusters to perform MSA on
            'msa_dir'		  => $self->o('msa_dir'), 
            'mafft_home'      => $self->o('mafft_home'),
	   },
        -hive_capacity => $self->o('mcoffee_capacity'),
		-rc_name       => 'msa_himem',
        -priority      => 35,
        -batch_size    => 50, 
    },

# ---------------------------------------------[BuildHMMprofiles-> building hmm profile step]---------------------------------------------------
    
    # Creating jobs for each multiple alignment file
	 {   -logic_name => 'HmmProfileFactory',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmProfileFactory',
         -parameters => {
	        'msa_dir'       => $self->o('msa_dir'),               
          },
         -flow_into  => {
                '2->A'	 => ['HmmBuild'],
 		  		'A->1' 	 => ['HmmCalibrateFactory'],
         },
        -wait_for => [ 'Mafft_BuildHMMprofiles' ],
     },

    # Run hmmbuild to create HMMer Profile
    {   -logic_name  => 'HmmBuild',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmBuild',
        -parameters  => {
              'hmmbuild_exe' => $self->o('hmmbuild_exe'),
              'hmmLib_dir'   => $self->o('hmmLib_dir'),
              'msa_dir'      => $self->o('msa_dir'),
         },
        -hive_capacity => $self->o('hmmbuild_capacity'),
        -rc_name       => 'msa_himem',
        -batch_size    => 50,
    },

    # Creating jobs for  calibration  HMMer Profile
	{   -logic_name => 'HmmCalibrateFactory',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrateFactory',
        -parameters => {
	        'hmmLib_dir'  => $self->o('hmmLib_dir'),               
         },
         'fan_branch_code' => 2,
         -flow_into => {
                '2->A'	 => ['HmmCalibrate'],
 		  		'A->1' 	 => ['load_models_BuildHMMprofiles'],
         },
         -wait_for  => [ 'HmmBuild' ],
     },

    # Run hmmcalibrate to calibrate created HMMer Profile
    {   -logic_name  => 'HmmCalibrate',
        -module      => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrate',
        -parameters  => {
	          'hmmLib_dir'    => $self->o('hmmLib_dir'),     
    	      'hmmcalibrate'  => $self->o('hmmcalibrate'),
           },
        -hive_capacity => $self->o('hmmcalibrate_capacity'),
        -batch_size    => 50,
    },

    {
        -logic_name => 'load_models_BuildHMMprofiles',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PantherLoadModels',
        -parameters => {
                          'cm_file_or_directory' => $self->o('hmmLib_dir'), 
                          'hmmer_path'           => $self->o('hmmer_path'), # For hmmemit (in case it is necessary to get the consensus for each model to create the blast db)
                          'pantherScore_path'    => $self->o('pantherScore_path'),
                          'hmmemit_exe'	   	     => $self->o('hmmemit_exe'),
#                          'type'				 => $self->o('hmm_profiles_type2'),
                       },
        -flow_into  => {
                          '1' => [ 'dump_models_BuildHMMprofiles' ],
                       },
    },

    {
        -logic_name => 'dump_models_BuildHMMprofiles',
        # Should dump only the newly built profiles
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpModels',
        -parameters => {
                          'hmm_library_basedir' => $self->o('hmmLib_dir'),
                          'blast_bin_dir'       => $self->o('blast_bin_dir'),  ## For creating the blastdb (formatdb or mkblastdb)
                          'pantherScore_path'   => $self->o('pantherScore_path'),
#                          'type'				=> $self->o('hmm_profiles_type2'),
                       },
        -flow_into  => {
                          '1' => [ 'HMMer_classify_factory' ],
                       },
    },

   { 
        -logic_name    => 'HMMer_classify_factory',
    	-module        => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyFactory',
    	-hive_capacity => -1,
        -flow_into 	   => {
        	    	        '2->A' => [ 'HMMer_classify_BuildHMMprofiles' ],
        					'A->1' => [ 'HMM_clusterize' ],
          				 },
   },

   {
             -logic_name => 'HMMer_classify_BuildHMMprofiles',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify',
             -parameters => {
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmmer_path'          => $self->o('hmmer_path'),
                             'hmm_library_basedir' => $self->o('hmmLib_dir'),
                             'cluster_dir'         => $self->o('cluster_dir'),
                             'blast_tmp_dir'	   => $self->o('blast_tmp_dir'),
                             'store_unclassify'	   => '0',
                            },
             -hive_capacity => $self->o('HMMer_classify_capacity'),
             -rc_name       => 'hmmclassify_job',
             -batch_size    => 50,
    },
  ) : (), # do not show the buildhmmprofile pipeline if the option is off
# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'blastdb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                'fan_branch_code'       => 2,
            },
            -flow_into  => {
                '2->A'  => [ 'dump_canonical_members' ],
                'A->1'  => [ 'reusedspecies_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'dump_canonical_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',
            -parameters => {
                'only_canonical'            => 1,
                'fasta_dir'                 => $self->o('fasta_dir'),
            },
            -rc_name       => '250Mb_job',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'make_blastdb' ],
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'fasta_dir'     => $self->o('fasta_dir'),
                'blast_bin_dir' => $self->o('blast_bin_dir'),
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_name#.blastdb_log -in #fasta_name#',
            },
        },

        {   -logic_name => 'members_against_allspecies_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory',
            -rc_name       => '250Mb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => [ 'blastp' ],
                'A->1' => [ 'hc_pafs' ],
            },
        },

        {   -logic_name => 'members_against_nonreusedspecies_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory',
            -parameters => {
                'species_set_id'    => '#nonreuse_ss_id#',
            },
            -rc_name       => '250Mb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => [ 'blastp' ],
                'A->1' => [ 'hc_pafs' ],
            },
        },

        {   -logic_name         => 'blastp',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'blast_params'              => $self->o('blast_params'),
                'fasta_dir'                 => $self->o('fasta_dir'),
                'blast_bin_dir'             => $self->o('blast_bin_dir'),
                'evalue_limit'              => 1e-10,
                'allow_same_species_hits'   => 1,
            },
            -batch_size    => 10,
            -rc_name       => '250Mb_job',
            -hive_capacity => $self->o('blastp_capacity'),
        },

        {   -logic_name         => 'hc_pafs',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'peptide_align_features',
            },
            %hc_analysis_params,
        },

# ---------------------------------------------[clustering step]---------------------------------------------------------------------

        {   -logic_name => 'hcluster_dump_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                'fan_branch_code'       => 2,
            },
            -flow_into  => {
                '2->A' => [ 'hcluster_dump_input_per_genome' ],
                'A->1' => [ 'hcluster_merge_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'hcluster_dump_input_per_genome',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare',
            -parameters => {
                'outgroups'     => $self->o('outgroups'),
                'cluster_dir'   => $self->o('cluster_dir'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name    => 'hcluster_merge_factory',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                '1->A' => {
                    'hcluster_merge_inputs' => [{'ext' => 'txt'}, {'ext' => 'cat'}],
                },
                'A->1' => [ 'hcluster_run' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name    => 'hcluster_merge_inputs',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cluster_dir'   => $self->o('cluster_dir'),
                'cmd'           => 'cat #cluster_dir#/*.hcluster.#ext# > #cluster_dir#/hcluster.#ext#',
            },
        },

        {   -logic_name    => 'hcluster_run',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
                'cluster_dir'                   => $self->o('cluster_dir'),
                'hcluster_exe'                  => $self->o('hcluster_exe'),
                'cmd'                           => '#hcluster_exe# -m #clustering_max_gene_halfcount# -w 0 -s 0.34 -O -C #cluster_dir#/hcluster.cat -o #cluster_dir#/hcluster.out #cluster_dir#/hcluster.txt',
            },
            -flow_into => {
                1 => [ 'hcluster_parse_output' ],
            },
            -rc_name => 'urgent_hcluster',
        },

        {   -logic_name => 'hcluster_parse_output',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput',
            -parameters => {
                'cluster_dir'               => $self->o('cluster_dir'),
                'additional_clustersets'    => [qw(phyml-aa phyml-nt nj-dn nj-ds nj-mm)],
                'division'                  => $self->o('division'),
            },
            -rc_name => '250Mb_job',
            -flow_into => [ 'hc_clusters' ],
        },

        {   -logic_name         => 'hc_clusters',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into          => [ 'run_qc_tests' ],
            %hc_analysis_params,
        },

# ---------------------------------------------[Pluggable QC step]----------------------------------------------------------

        {   -logic_name => 'run_qc_tests',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },
                'fan_branch_code'       => 2,
            },
            -flow_into => {
                '2->A' => [ 'per_genome_qc' ],
                '1->A' => [ 'overall_qc' ],
                'A->1' => [ 'clusterset_backup' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'overall_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('prev_rel_db'),
                'cluster_dir'               => $self->o('cluster_dir'),
            },
            -hive_capacity  => $self->o('qc_capacity'),
            -failed_job_tolerance => 0,
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'per_genome_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('prev_rel_db'),
            },
            -hive_capacity => $self->o('qc_capacity'),
            -failed_job_tolerance => 0,
        },

        {   -logic_name    => 'clusterset_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT INTO gene_tree_backup (member_id, root_id) SELECT member_id, root_id FROM gene_tree_node WHERE member_id IS NOT NULL',
            },
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
        },


# ---------------------------------------------[main tree fan]-------------------------------------------------------------

        {   -logic_name => 'large_cluster_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" GROUP BY root_id HAVING COUNT(member_id) >= #treebreak_gene_count#',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                 '2->A' => [ 'launch_large_cluster_break' ],
                 '1->A' => [ 'cluster_factory' ],
                 'A->1' => [ 'hc_global_tree_set' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'cluster_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" GROUP BY root_id HAVING COUNT(member_id) < #treebreak_gene_count# ORDER BY COUNT(*) DESC, root_id ASC',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'msa_chooser' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into  => [
                $self->o('do_stable_id_mapping') ? 'stable_id_mapping' : (),
                $self->o('do_treefam_xref') ? 'treefam_xref_idmap' : (),
            ],
            %hc_analysis_params,
        },

        {   -logic_name => 'msa_chooser',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSAChooser',
            -parameters => {
                'mafft_gene_count'      => $self->o('mafft_gene_count'),
                'mafft_runtime'         => $self->o('mafft_runtime'),
            },
            -batch_size => 10,
            -hive_capacity => 100,
            -flow_into => {
                '2->A' => [ 'mcoffee' ],
                '3->A' => [ 'mafft' ],
                'A->1' => [ 'hc_alignment_pre_tree' ],
            },
        },

        {   -logic_name => 'launch_large_cluster_break',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                '1->A' => [ 'mafft' ],
                'A->1' => [ 'hc_alignment_pre_tree_break' ],
            },
            -meadow_type    => 'LOCAL',
        },

# ---------------------------------------------[Pluggable MSA steps]----------------------------------------------------------

        {   -logic_name => 'mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'mafft_home'            => $self->o('mafft_home'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name => 'msa',
            -flow_into => {
               -1 => [ 'mcoffee_himem' ],  # MEMLIMIT
               -2 => [ 'mafft' ],
            },
        },

        {   -logic_name => 'mafft',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_home'                 => $self->o('mafft_home'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name => 'msa',
            -flow_into => {
               -1 => [ 'mafft_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'mafft_home'            => $self->o('mafft_home'),
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name => 'msa_himem',
            -flow_into => {
               -2 => [ 'mafft_himem' ],
            },
        },

        {   -logic_name => 'mafft_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_home'                 => $self->o('mafft_home'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name => 'msa_himem',
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name         => 'hc_alignment_pre_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -flow_into          => [ 'split_genes' ],
            %hc_analysis_params,
        },

        {   -logic_name     => 'split_genes',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '500Mb_job',
            -batch_size     => 20,
            -flow_into      => [ 'njtree_phyml', 'build_HMM_aa', 'build_HMM_cds' ],
        },

        {   -logic_name => 'njtree_phyml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'bootstrap'                 => 1,
                'store_intermediate_trees'  => 1,
                'store_filtered_align'      => 1,
                'treebest_exe'              => $self->o('treebest_exe'),
            },
            -hive_capacity        => $self->o('njtree_phyml_capacity'),
            -rc_name => '4Gb_job',
            -flow_into => {
                '1->A' => [ 'hc_alignment_post_tree', 'hc_tree_structure' ],
                'A->1' => [ 'ortho_tree' ],
                 1     => [ 'ktreedist' ],
                '2->B' => [ 'hc_tree_structure' ],
                'B->2' => [ 'ortho_tree_annot' ],
            }
        },

        {   -logic_name         => 'hc_alignment_post_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_tree_structure',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_structure',
            },
            %hc_analysis_params,
        },

        {   -logic_name => 'ortho_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
            },
            -hive_capacity      => $self->o('ortho_tree_capacity'),
            -rc_name => '250Mb_job',
            -flow_into  => [ 'hc_tree_attributes', 'hc_tree_homologies' ],
        },

        {   -logic_name         => 'hc_tree_attributes',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_attributes',
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_tree_homologies',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_homologies',
            },
            %hc_analysis_params,
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters    => {
                               'treebest_exe'  => $self->o('treebest_exe'),
                               'ktreedist_exe' => $self->o('ktreedist_exe'),
                              },
            -hive_capacity => $self->o('ktreedist_capacity'),
            -batch_size => 5,
            -rc_name       => '2Gb_job',
        },

        {   -logic_name => 'ortho_tree_annot',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'store_homologies'  => 0,
            },
            -hive_capacity        => $self->o('ortho_tree_annot_capacity'),
            -rc_name => '250Mb_job',
            -batch_size => 20,
            -flow_into  => [ 'hc_tree_attributes' ],
        },

        {   -logic_name => 'build_HMM_aa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'buildhmm_exe'      => $self->o('buildhmm_exe'),
            },
            -hive_capacity        => $self->o('build_hmm_capacity'),
            -batch_size           => 5,
            -priority             => -10,
            -rc_name => '500Mb_job',
        },

        {   -logic_name => 'build_HMM_cds',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'cdna'              => 1,
                'buildhmm_exe'      => $self->o('buildhmm_exe'),
            },
            -hive_capacity        => $self->o('build_hmm_capacity'),
            -batch_size           => 5,
            -priority             => -10,
            -rc_name => '1Gb_job',
        },

# ---------------------------------------------[Quick tree break steps]-----------------------------------------------------------------------

        {   -logic_name         => 'hc_alignment_pre_tree_break',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -flow_into          => [ 'quick_tree_break' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'quick_tree_break',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
            -parameters => {
                'quicktree_exe'     => $self->o('quicktree_exe'),
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
            },
            -hive_capacity        => $self->o('quick_tree_break_capacity'),
            -rc_name   => '2Gb_job',
            -flow_into => [ 'other_paralogs' ],
        },

        {   -logic_name     => 'other_paralogs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
            -parameters     => {
                'dataflow_subclusters' => 1,
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_name        => '250Mb_job',
            -flow_into      => {
                2 => [ 'tree_backup' ],
            }
        },

        {   -logic_name    => 'tree_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT INTO gene_tree_backup (member_id, root_id) SELECT member_id, root_id FROM gene_tree_node WHERE member_id IS NOT NULL AND root_id = #gene_tree_id#',
            },
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
            #-flow_into      => [ 'mafft' ],
            -flow_into => {
                '1->A' => [ 'mafft' ],
                'A->1' => [ 'hc_alignment_pre_tree' ],
            },
        },



# -------------------------------------------[name mapping step]---------------------------------------------------------------------

        {
            -logic_name => 'stable_id_mapping',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters => {
                'master_db'     => $self->o('master_db'),
                'prev_rel_db'   => $self->o('prev_rel_db'),
                'type'          => 't',
            },
            -rc_name => '1Gb_job',
        },

        {   -logic_name    => 'treefam_xref_idmap',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper',
            -parameters    => {
                'tf_release'  => $self->o('tf_release'),
                'tag_prefix'  => '',
            },
            -rc_name => '1Gb_job',
        },

# ---------------------------------------------[homology step]-----------------------------------------------------------------------

        {   -logic_name => 'group_genomes_under_taxa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa',
            -parameters => {
                'taxlevels'             => $self->o('taxlevels'),
                'filter_high_coverage'  => $self->o('filter_high_coverage'),
            },
            -flow_into => {
                2 => [ 'mlss_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory',
            -flow_into => {
                2 => [ 'homology_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'homology_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
            -flow_into => {
                'A->1' => [ 'hc_dnds' ],
                '2->A' => [ 'homology_dNdS' ],
            },
        },

        {   -logic_name => 'homology_dNdS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Homology_dNdS',
            -parameters => {
                'codeml_parameters_file'    => $self->o('codeml_parameters_file'),
                'codeml_exe'                => $self->o('codeml_exe'),
            },
            -hive_capacity        => $self->o('homology_dNdS_capacity'),
            -failed_job_tolerance => 2,
            -rc_name => '500Mb_job',
        },

        {   -logic_name         => 'hc_dnds',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'homology_dnds',
            },
            -flow_into          => [ 'threshold_on_dS' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'threshold_on_dS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
        },

    ];
}

sub resource_classes {
    my $self = shift;
    return {
      'default'  	 => { 'LSF' => '-q production-rh6 -n 4 -M 4000 -R "rusage[mem=4000]"'},
      'mem'     	 => { 'LSF' => '-q production-rh6 -n 4 -M 12000 -R "rusage[mem=12000]"'},
      '2Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
      '4Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
      '24Gb_job'     => {'LSF' => '-q production-rh6 -C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
      '250Mb_job'    => {'LSF' => '-q production-rh6 -C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
      '500Mb_job'    => {'LSF' => '-q production-rh6 -C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
	  '1Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
	  '2Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
	  '8Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
	  '24Gb_job'     => {'LSF' => '-q production-rh6 -C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
	  'msa'          => {'LSF' => '-q production-rh6 -W 24:00' },
	  'msa_himem'    => {'LSF' => '-q production-rh6 -M 32768 -R "rusage[mem=32768]" -W 24:00' },
	  'urgent_hcluster' => {'LSF' => '-q production-rh6 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
	  'hmmclassify_job' => {'LSF' => '-q production-rh6 -C0 -M8000  -R"select[(mem>8000)&&nfs_nobackup2]  rusage[mem=8000]"' },
    }
}

1;

