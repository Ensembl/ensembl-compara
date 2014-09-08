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

Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

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

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details
        #'email'                 => 'john.smith@example.com',

    # parameters that are likely to change from execution to another:
        #'mlss_id'               => 40077,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        #'ensembl_release'       => 68,      # it defaults to Bio::EnsEMBL::ApiVersion::software_version(): you're unlikely to change the value
        'do_not_reuse_list'     => [ ],     # names of species we don't want to reuse this time
        'method_link_dump_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/method_link.txt',

    # custom pipeline name, in case you don't like the default one
        #'pipeline_name'         => 'compara_homology_'.$self->o('ensembl_release'),
        'division'              => undef,       # Tag attached to every single tree

    # dependent parameters: updating 'work_dir' should be enough
        #'work_dir'              => '/lustre/scratch101/ensembl/'.$self->o('ENV', 'USER').'/protein_trees_'.$self->o('rel_with_suffix'),
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',
        'dump_dir'              => $self->o('work_dir') . '/dumps',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 0,
        'allow_pyrrolysine'         => 0,

    # blast parameters:
        'blast_params'              => '-seg no -max_hsps_per_subject 1 -use_sw_tback -num_threads 1',

        'protein_members_range'     => 100000000, # highest member_id for a protein member

    # clustering parameters:
        'outgroups'                     => {},      # affects 'hcluster_dump_input_per_genome'
        'clustering_max_gene_halfcount' => 750,     # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'

    # tree building parameters:
        'use_raxml'                 => 0,
        'use_notung'                => 0,
        'use_raxml_epa_on_treebest' => 0,
        'treebreak_gene_count'      => 400,     # affects msa_chooser
        'mafft_gene_count'          => 200,     # affects msa_chooser
        'mafft_runtime'             => 7200,    # affects msa_chooser
        'raxml_threshold_n_genes' => 500,
        'raxml_threshold_aln_len' => 2500,
        'raxml_cores'             => 16,

    # alignment filtering options
        'threshold_n_genes'       => 20,
        'threshold_aln_len'       => 1000,
        'threshold_n_genes_large' => 2000,
        'threshold_aln_len_large' => 15000,
        'noisy_cutoff'            => 0.4,
        'noisy_cutoff_large'      => 1,

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
        'species_tree_input_file'   => undef,
        # you can define your own species_tree for 'notung'. It *has* to be binary
        'binary_species_tree_input_file'   => undef,

    # homology assignment for polyploid genomes
        # This parameter is an array of groups of genome_db names / IDs.
        # Each group represents the components of a polyploid genome
        'homoeologous_genome_dbs'   => [],


    # homology_dnds parameters:
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/protein_trees.codeml.ctl.hash',      # used by 'homology_dNdS'
        'taxlevels'                 => [],
        'filter_high_coverage'      => 0,   # affects 'group_genomes_under_taxa'

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 0,
        'tf_release'                => undef,       # The TreeFam release to map to

    # executable locations:
        #'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        #'mcoffee_home'              => '/software/ensembl/compara/tcoffee/Version_9.03.r1318/',
        #'mafft_home'                => '/software/ensembl/compara/mafft-7.113/',
        #'trimal_exe'                => '/software/ensembl/compara/trimAl/trimal-1.2',
        #'noisy_exe'                 => '/software/ensembl/compara/noisy/noisy-1.5.12',
        #'prottest_jar'              => '/software/ensembl/compara/prottest/prottest-3.4.jar',
        #'treebest_exe'              => '/software/ensembl/compara/treebest',
        #'raxml_exe'                 => '/software/ensembl/compara/raxml/raxmlHPC-SSE3-8.1.3',
        #'notung_jar'                => '/software/ensembl/compara/notung/Notung-2.6.jar',
        #'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        #'buildhmm_exe'              => '/software/ensembl/compara/hmmer-3.1b1/binaries/hmmbuild',
        #'codeml_exe'                => '/software/ensembl/compara/paml43/bin/codeml',
        #'ktreedist_exe'             => '/software/ensembl/compara/ktreedist/Ktreedist.pl',
        #'blast_bin_dir'             => '/software/ensembl/compara/ncbi-blast-2.2.28+/bin',

    # HMM specific parameters (set to 0 or undef if not in use)
        #'hmm_clustering'            => 0, ## by default run blastp clustering
        #'cm_file_or_directory'      => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        #'hmm_library_basedir'       => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        ##'cm_file_or_directory'      => '/lustre/scratch110/ensembl/mp12/panther_hmms/PANTHER7.2_ascii', ## Panther DB
        ##'hmm_library_basedir'       => '/lustre/scratch110/ensembl/mp12/Panther_hmms',
        #'pantherScore_path'         => '/software/ensembl/compara/pantherScore1.03',
        #'hmmer_path'                => '/software/ensembl/compara/hmmer-2.3.2/src/',
        'extra_model_tags_file'     => undef,

    # hive_capacity values for some analyses:
        #'reuse_capacity'            =>   3,
        #'blast_factory_capacity'    =>  50,
        #'blastp_capacity'           => 900,
        #'mcoffee_capacity'          => 600,
        #'split_genes_capacity'      => 600,
        #'alignment_filtering_capacity'  => 400,
        #'prottest_capacity'         => 400,
        #'treebest_capacity'         => 400,
        #'raxml_capacity'            => 400,
        #'notung_capacity'           => 400,
        #'ortho_tree_capacity'       => 200,
        #'ortho_tree_annot_capacity' => 300,
        #'quick_tree_break_capacity' => 100,
        #'build_hmm_capacity'        => 200,
        #'ktreedist_capacity'        => 150,
        #'merge_supertrees_capacity' => 100,
        #'other_paralogs_capacity'   => 100,
        #'homology_dNdS_capacity'    => 200,
        #'qc_capacity'               =>   4,
        #'hc_capacity'               =>   4,
        #'HMMer_classify_capacity'   => 100,
        #'loadmembers_capacity'      =>  30,

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => -10,

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        #'host' => 'compara1',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@compara1:3306/sf5_ensembl_compara_master',
        'master_db' => undef,
        'ncbi_db'   => $self->o('master_db'),
        'master_db_is_missing_dnafrags' => 0,

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        #'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        #'curr_core_registry'        => "registry.conf",
        'curr_core_registry'        => undef,
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        #'prev_core_sources_locs'   => [ $self->o('livemirror_loc') ],

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        #'prev_rel_db' => 'mysql://ensro@compara3:3306/mm14_compara_homology_67'

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   clusters means that the members, the blastp hits and the clusters are copied over. In this case, the blastp hits are actually not copied over if "skip_blast_copy_if_possible" is set
        #   blastp means that only the members and the blastp hits are copied over
        #   members means that only the members are copied over
        'reuse_level'               => 'clusters',
        # If all the species can be reused, and if the reuse_level is "clusters", do we really want to copy all the peptide_align_feature tables ?
        'skip_blast_copy_if_possible'   => 1,

    };
}


=head2 RESOURCE CLASSES

# This section has to be filled in any derived class
sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '250Mb_job'    => {'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '4Gb_8c_job'   => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"  -n 8' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '8Gb_8c_job'   => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"  -n 8' },
         '16Gb_job'     => {'LSF' => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '16Gb_long_job'=> {'LSF' => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]" -q long' },
         '32Gb_job'     => {'LSF' => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         '64Gb_job'     => {'LSF' => '-C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"' },

         'urgent_hcluster'      => {'LSF' => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
    };
}

=cut


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
    die "Cannot refine TreeBest's trees with RAxML EPA in RAxML mode (because TreeBest is only run on small trees, and cannot produce long branches)" if $self->o('use_raxml') and $self->o('use_raxml_epa_on_treebest') and not ($self->o('use_raxml') =~ /^#:subst/);

    # Without a master database, we must provide other parameters
    die if not $self->o('master_db') and not $self->o('ncbi_db');

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        'mkdir -p '.$self->o('cluster_dir'),
        'mkdir -p '.$self->o('dump_dir'),
        'mkdir -p '.$self->o('fasta_dir'),

            # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('fasta_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('fasta_dir').' -c -1 || echo "Striping is not available on this system" ',
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'master_db'     => $self->o('master_db'),
        'ncbi_db'       => $self->o('ncbi_db'),
        'reuse_db'      => $self->o('prev_rel_db'),

        'cluster_dir'   => $self->o('cluster_dir'),
        'fasta_dir'     => $self->o('fasta_dir'),
        'dump_dir'      => $self->o('dump_dir'),

        'reuse_level'   => $self->o('reuse_level'),
        'hmm_clustering'    => $self->o('hmm_clustering'),
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
                'output_file'   => '#dump_dir#/#filename#.sql.gz',
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
                'filename'          => 'snapshot_1_before_genome_load',
            },
            -flow_into  => {
                '1->A'  => [ 'genome_reuse_factory' ],
                'A->1'  => [ 'should_blast_be_skipped' ],
            },
        },

        {   -logic_name => 'should_blast_be_skipped',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'skip_blast_copy_if_possible'   => $self->o('skip_blast_copy_if_possible'),
                'condition'     => '(#are_all_species_reused# and #skip_blast_copy_if_possible#) or #hmm_clustering#',
            },
            -flow_into => {
                2 => [ 'backbone_fire_clustering' ],
                3 => [ 'backbone_fire_allvsallblast' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'backbone_fire_allvsallblast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => '',
                'filename'      => 'snapshot_2_before_allvsallblast',
            },
            -flow_into  => {
                '1->A'  => [ 'blastdb_factory' ],
                'A->1'  => [ 'backbone_fire_clustering' ],
            },
        },

        {   -logic_name => 'backbone_fire_clustering',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => '',
                'filename'      => 'snapshot_3_before_clustering',
            },
            -flow_into  => {
                '1->A'  => [ 'check_whether_can_copy_clusters' ],
                'A->1'  => [ 'backbone_fire_tree_building' ],
            },
        },

        {   -logic_name => 'backbone_fire_tree_building',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'filename'      => 'snapshot_4_before_tree_building',
            },
            -flow_into  => {
                '1->A'  => [ 'cluster_factory' ],
                'A->1'  => [ 'backbone_fire_dnds' ],
            },
        },

        {   -logic_name => 'backbone_fire_dnds',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'filename'      => 'snapshot_5_before_dnds',
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
                'src_db_conn'   => '#ncbi_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'select_method_links_source',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'condition'     => '$self->param_is_defined("master_db")',
            },
            -flow_into => {
                2 => [ 'populate_method_links_from_db' ],
                3 => [ 'populate_method_links_from_file' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name    => 'populate_method_links_from_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#master_db#',
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
                'compara_db'            => '#master_db#',   # that's where genome_db_ids come from

                'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', ['fetch_by_dbID', $self->o('mlss_id')], 'species_set_obj', 'genome_dbs'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator', 'has_karyotype' => 'has_karyotype', 'is_high_coverage' => 'is_high_coverage' },

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
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
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
            },
            -flow_into => [ 'make_treebest_species_tree' ],
            -meadow_type    => 'LOCAL',
        },


# ---------------------------------------------[load species tree]-------------------------------------------------------------------

        {   -logic_name    => 'make_treebest_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                               'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                               'do_transactions' => 1,
            },
            -flow_into     => {
                2 => [ 'hc_species_tree' ],
            }
        },

        {   -logic_name         => 'hc_species_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'species_tree',
                binary          => 0,
            },
            -flow_into  => {
                $self->o('use_notung') ? 1 : 999 => [ 'has_user_provided_binary_species_tree' ],
            },
            %hc_analysis_params,
        },

        {   -logic_name => 'has_user_provided_binary_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'condition'     => $self->o('binary_species_tree_input_file') ? 1 : 0,
            },
            -flow_into => {
                2 => [ 'load_binary_species_tree' ],
                3 => [ 'make_binary_species_tree' ],
            },
            -meadow_type    => 'LOCAL',
        },

         {   -logic_name    => 'load_binary_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                               'label' => 'binary',
                               'species_tree_input_file' => $self->o('binary_species_tree_input_file'),
                               'do_transactions' => 1,
            },
            -flow_into     => {
                2 => [ 'hc_binary_species_tree' ],
            }
        },

        {   -logic_name    => 'make_binary_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree',
            -parameters    => {
                'new_label'     => 'binary',
                'tree_fmt'      => '%{-x"*"}:%{d}',
                'label'         => 'default',
            },
            -flow_into     => {
                2 => [ 'hc_binary_species_tree' ],
            }
        },

        {   -logic_name         => 'hc_binary_species_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'species_tree',
                binary          => 1,
            },
            %hc_analysis_params,
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
                'A->1' => [ 'load_fresh_members_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => '#reuse_db#',
                            'inputquery' => 'SELECT s.* FROM sequence s JOIN seq_member USING (sequence_id) WHERE sequence_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                            'fan_branch_code' => 2,
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '500Mb_job',
            -flow_into => {
                2 => [ ':////sequence' ],
                1 => [ 'dnafrag_table_reuse' ],
            },
        },

        {   -logic_name => 'dnafrag_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'topup',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'seq_member_table_reuse' ],
            },
        },

        {   -logic_name => 'seq_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'seq_member',
                'where'         => 'seq_member_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                'mode'          => 'topup',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'gene_member_table_reuse' ],
            },
        },

        {   -logic_name => 'gene_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'gene_member',
                'where'         => 'gene_member_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                'mode'          => 'topup',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'reset_gene_member_counters' ],
            },
        },

        {   -logic_name => 'reset_gene_member_counters',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'UPDATE gene_member SET families = 0, gene_trees = 0, gene_gain_loss_trees = 0, orthologues = 0, paralogues = 0, homoeologues = 0 WHERE genome_db_id = #genome_db_id#' ],
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'other_sequence_table_reuse' ],
            },
        },

        {   -logic_name => 'other_sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => '#reuse_db#',
                            'inputquery' => 'SELECT s.seq_member_id, s.seq_type, s.length, s.sequence FROM other_member_sequence s JOIN seq_member USING (seq_member_id) WHERE genome_db_id = #genome_db_id# AND seq_type IN ("cds", "exon_bounded") AND seq_member_id <= '.$self->o('protein_members_range'),
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
                mode            => 'members_per_genome',
                allow_ambiguity_codes => $self->o('allow_ambiguity_codes'),
            },
            %hc_analysis_params,
        },


# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'load_fresh_members_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name, locator FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #nonreuse_ss_id#',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                '2->A' => [ 'is_genome_in_db' ],
                'A->1' => [ 'hc_members_globally' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'is_genome_in_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'condition'     => '"#locator#" =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/',
            },
            -flow_into => {
                2 => [ 'is_there_master_db' ],
                3 => [ 'load_fresh_members_from_file' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'is_there_master_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'condition'     => '$self->param_is_defined("master_db")',
            },
            -flow_into => {
                2 => [ 'copy_dnafrags_from_master' ],
                3 => { 'load_fresh_members_from_db' => { 'genome_db_id' => '#genome_db_id#', 'store_missing_dnafrags' => 1} },
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'copy_dnafrags_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'topup',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'load_fresh_members_from_db' ],
        },

        {   -logic_name => 'load_fresh_members_from_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'store_related_pep_sequences' => 1,
                'allow_pyrrolysine'             => $self->o('allow_pyrrolysine'),
                'find_canonical_translations_for_polymorphic_pseudogene' => 1,
                'store_missing_dnafrags'        => $self->o('master_db_is_missing_dnafrags'),
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
            -rc_name => '2Gb_job',
            -flow_into => [ 'hc_members_per_genome' ],
        },

        {   -logic_name => 'load_fresh_members_from_file',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembersFromFiles',
            -parameters => {
                -need_cds_seq   => 1,
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
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
                '_force_blast_run'   => '#expr(#reuse_level# eq "members" ? 1 : 0)expr#',
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #reuse_ss_id# AND NOT #_force_blast_run#',
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
                '_force_blast_run'   => '#expr(#reuse_level# eq "members" ? 1 : 0)expr#',
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #nonreuse_ss_id# OR #_force_blast_run#',
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
                'src_db_conn'   => '#reuse_db#',
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
            {
            -logic_name => 'load_models',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PantherLoadModels',
             -parameters => {
                             'cm_file_or_directory' => $self->o('cm_file_or_directory'),
                             'hmmer_path'           => $self->o('hmmer_path'), # For hmmemit (in case it is necessary to get the consensus for each model to create the blast db)
                             'pantherScore_path'    => $self->o('pantherScore_path'),
                            },
             -flow_into  => [ 'dump_models' ],
            },

            {
             -logic_name => 'dump_models',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpModels',
             -parameters => {
                             'hmm_library_basedir' => $self->o('hmm_library_basedir'),
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),  ## For creating the blastdb (formatdb or mkblastdb)
                             'pantherScore_path'    => $self->o('pantherScore_path'),
                            },
             -flow_into  => [ 'HMMer_factory' ],
            },

            {
             -logic_name  => 'HMMer_factory',
             -module      => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
             -parameters  => {
                              'call_list'            => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all' ],
                              'column_names2getters' => { 'genome_db_id' => 'dbID' },
                              'fan_branch_code'      => 2,
                             },
             -flow_into  => {
                             '2->A' => [ 'HMMer_classify' ],
                             'A->1' => [ 'HMM_clusterize' ]
                            },
            },

            {
             -logic_name => 'HMMer_classify',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify',
             -parameters => {
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmmer_path'          => $self->o('hmmer_path'),
                             'hmm_library_basedir' => $self->o('hmm_library_basedir'),
                            },
             -hive_capacity => $self->o('HMMer_classify_capacity'),
             -rc_name => '8Gb_job',
            },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClusterize',
             -parameters => {
                 'division'     => $self->o('division'),
                 'extra_tags_file'  => $self->o('extra_model_tags_file'),
             },
             -rc_name => '8Gb_job',
            },


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
            },
            -rc_name       => '250Mb_job',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'make_blastdb' ],
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
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

        {   -logic_name => 'go_for_hmm_clustering',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'condition'     => '#hmm_clustering#',
            },
            -flow_into => {
                2 => 'load_models',
                3 => 'hcluster_dump_factory',
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'check_whether_can_copy_clusters',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow',
            -parameters    => {
                'condition'     => '#are_all_species_reused# and ("#reuse_level#" eq "clusters")',
            },
            -flow_into => {
                '2->A' => [ 'copy_clusters' ],
                '3->A' => [ 'go_for_hmm_clustering' ],
                'A->1' => [ 'hc_clusters' ],
            },
            -meadow_type    => 'LOCAL',
        },

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
                'cmd'           => 'cat #cluster_dir#/*.hcluster.#ext# > #cluster_dir#/hcluster.#ext#',
            },
        },

        {   -logic_name    => 'hcluster_run',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
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
                'division'                  => $self->o('division'),
            },
            -rc_name => '250Mb_job',
        },

        {   -logic_name => 'copy_clusters',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyClusters',
            -parameters => {
                'tags_to_copy'              => [ 'division' ],
            },
            -rc_name => '500Mb_job',
        },


        {   -logic_name         => 'hc_clusters',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into          => [ 'create_additional_clustersets' ],
            %hc_analysis_params,
        },

        {   -logic_name         => 'create_additional_clustersets',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
            -parameters         => {
                member_type     => 'protein',
                'additional_clustersets'    => [qw(treebest phyml-aa phyml-nt nj-dn nj-ds nj-mm raxml raxml_bl notung)],
            },
            -flow_into          => [ 'run_qc_tests' ],
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
            -hive_capacity  => $self->o('qc_capacity'),
            -failed_job_tolerance => 0,
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'per_genome_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PerGenomeGroupsetQC',
            -hive_capacity => $self->o('qc_capacity'),
            -failed_job_tolerance => 0,
        },

        {   -logic_name    => 'clusterset_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT IGNORE INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL',
            },
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
        },


# ---------------------------------------------[main tree fan]-------------------------------------------------------------

        {   -logic_name => 'cluster_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="default"',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                 '2->A' => [ 'alignment_entry_point' ],
                 'A->1' => [ 'hc_global_tree_set' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'alignment_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                 '1->A' => [ 'large_clusters_go_to_mafft' ],
                 'A->1' => [ 'hc_alignment' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'large_clusters_go_to_mafft',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow',
            -parameters => {
                'condition'             => '#tree_gene_count# > #mafft_gene_count#',
                'mafft_gene_count'      => $self->o('mafft_gene_count'),
            },
            -flow_into  => {
                2 => [ 'mafft' ],
                3 => [ 'long_running_clusters_go_to_mafft' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'long_running_clusters_go_to_mafft',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow',
            -parameters => {
                'condition'             => '#tree_reuse_aln_runtime#/1000 > #mafft_runtime#',
                'defaults'              => { 'tree_reuse_aln_runtime' => 0 },
                'mafft_runtime'         => $self->o('mafft_runtime'),
            },
            -flow_into  => {
                2 => [ 'mafft' ],
                3 => [ 'mcoffee' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name => 'very_large_clusters_go_to_qtb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow',
            -parameters => {
                'condition'             => '#tree_gene_count# > #treebreak_gene_count#',
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
            },
            -flow_into  => {
                2  => [ 'quick_tree_break' ],
                3  => [ 'tree_entry_point' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into  => [
                'write_stn_tags',
                $self->o('do_stable_id_mapping') ? 'stable_id_mapping' : (),
                $self->o('do_treefam_xref') ? 'treefam_xref_idmap' : (),
            ],
            %hc_analysis_params,
        },

        {   -logic_name     => 'write_stn_tags',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'stnt_sql_script'   => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/tree-stats-as-stn_tags.sql',
                'command_line_db'   => $self->dbconn_2_mysql('pipeline_db', 1),
                'cmd'               => 'mysql  #command_line_db# < #stnt_sql_script#',
            },
            -flow_into      => [ 'email_tree_stats_report' ],
        },

        {   -logic_name     => 'email_tree_stats_report',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport',
            -parameters     => {
                'email' => $self->o('email'),
            },
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
            -rc_name    => '2Gb_job',
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
            -rc_name    => '2Gb_job',
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
            -rc_name    => '8Gb_job',
            -flow_into => {
               -1 => [ 'mafft_himem' ],
               -2 => [ 'mafft_himem' ],
            },
        },

        {   -logic_name => 'mafft_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_home'                 => $self->o('mafft_home'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
        },

        {   -logic_name         => 'hc_alignment',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -flow_into => [ 'very_large_clusters_go_to_qtb' ],
            %hc_analysis_params,
        },


# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name     => 'split_genes',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '500Mb_job',
            -batch_size     => 20,
            -flow_into      => {
                1   => $self->o('use_raxml') ? 'filter_decision' : 'treebest',
                999 => $self->o('use_raxml') ? 'treebest' : 'filter_decision',
                -1  => 'split_genes_himem',
            },
        },

        {   -logic_name     => 'split_genes_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '4Gb_job',
            -flow_into      => {
                1   => $self->o('use_raxml') ? 'filter_decision' : 'treebest',
                999 => $self->o('use_raxml') ? 'treebest' : 'filter_decision',
            },
        },

        {   -logic_name => 'tree_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -meadow_type    => 'LOCAL',
            -flow_into  => {
                '1->A'   => [ 'split_genes' ],
                'A->1'   => [ 'hc_alignment_post_tree' ],
            },
        },

        {   -logic_name => 'filter_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow',
            -parameters => {
                'condition'              => '(#tree_gene_count# <= #threshold_n_genes#) || (#tree_aln_length# <= #threshold_aln_len#)',
                'threshold_n_genes'      => $self->o('threshold_n_genes'),
                'threshold_aln_len'      => $self->o('threshold_aln_len'),
            },
            -flow_into  => {
                2 => [ 'aln_filtering_tagging' ],
                3 => [ 'filtering_strictness' ],
            },
        },

        {   -logic_name => 'filtering_strictness',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow',
            -parameters => {
                'condition'                    => '(#tree_gene_count# >= #threshold_n_genes_large#) || (#tree_aln_length# >= #threshold_aln_len_large#)',
                'threshold_n_genes_large'      => $self->o('threshold_n_genes_large'),
                'threshold_aln_len_large'      => $self->o('threshold_aln_len_large'),
            },
            -flow_into  => {
                2 => [ 'noisy_large' ],
                3 => [ 'noisy' ],
                999 => [ 'trimal' ],
            },
        },

        {   -logic_name     => 'noisy',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy',
            -parameters => {
                'noisy_exe'    => $self->o('noisy_exe'),
                               'noisy_cutoff' => $self->o('noisy_cutoff'),
            },
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name           => '4Gb_job',
            -batch_size     => 5,
            -flow_into      => [ 'aln_filtering_tagging' ],
        },

        {   -logic_name     => 'noisy_large',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy',
            -parameters => {
                'noisy_exe'    => $self->o('noisy_exe'),
                               'noisy_cutoff'  => $self->o('noisy_cutoff_large'),
            },
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name           => '16Gb_job',
            -batch_size     => 5,
            -flow_into      => [ 'aln_filtering_tagging' ],
        },


        {   -logic_name     => 'trimal',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::TrimAl',
            -parameters => {
                'trimal_exe'    => $self->o('trimal_exe'),
            },
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name        => '500Mb_job',
            -batch_size     => 5,
            -flow_into      => [ 'aln_filtering_tagging' ],
        },

        {   -logic_name     => 'aln_filtering_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentFilteringTagging',
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -batch_size     => 5,
            -flow_into      => [ 'prottest' ],
        },

        {   -logic_name => 'prottest',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'prottest_memory'       => 3500,
                'escape_branch'         => -1,
                'n_cores'               => 8,
            },
            -hive_capacity        => $self->o('prottest_capacity'),
            -rc_name    => '4Gb_8c_job',
            -flow_into  => {
                -1 => [ 'prottest_himem' ],
                1 => [ 'raxml' ],
            }
        },

        {   -logic_name => 'prottest_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'prottest_memory'       => 7000,
                'escape_branch'         => -1,      # RAxML will use a default model, anyway
                'n_cores'               => 8,
            },
            -hive_capacity        => $self->o('prottest_capacity'),
            -rc_name    => '8Gb_8c_job',
            -flow_into  => [ 'raxml_himem' ],
        },

        {   -logic_name => 'treebest',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'bootstrap'                 => 1,
                'store_intermediate_trees'  => 1,
                'store_filtered_align'      => 1,
                'extra_args'                => $self->o('use_raxml') ? ' -F 0 ' : '',
                'treebest_exe'              => $self->o('treebest_exe'),
                'output_clusterset_id'      => $self->o('use_raxml_epa_on_treebest') ? 'treebest' : 'default',
            },
            -hive_capacity        => $self->o('treebest_capacity'),
            -rc_name    => '4Gb_job',
            -flow_into  => {
                $self->o('use_raxml_epa_on_treebest') ? 1 : 999 => [ 'raxml_epa_longbranches' ],
            }
        },

        {   -logic_name => 'raxml_epa_longbranches',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_EPA_lb',
            -parameters => {
                'raxml_exe'                 => $self->o('raxml_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'input_clusterset_id'       => 'treebest',
                'output_clusterset_id'      => $self->o('use_notung') ? 'raxml_bl' : 'default',
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '4Gb_job',
            -flow_into  => {
                $self->o('use_notung') ? 1 : 999 => [ 'notung' ],
                2 => [ 'promote_treebest_tree' ],
                4 => [ 'raxml_bl_unfiltered' ],
                -1 => [ 'raxml_epa_longbranches_himem' ],
            },
        },

        {   -logic_name => 'raxml_epa_longbranches_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_EPA_lb',
            -parameters => {
                'raxml_exe'                 => $self->o('raxml_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'input_clusterset_id'       => 'treebest',
                'output_clusterset_id'      => $self->o('use_notung') ? 'raxml_bl' : 'default',
                'raxml_extra_params'        => '-U',
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '16Gb_job',
            -flow_into  => {
                $self->o('use_notung') ? 1 : 999 => [ 'notung' ],
                2 => [ 'promote_treebest_tree' ],
                4 => [ 'raxml_bl_unfiltered' ],
            },
        },

        {   -logic_name => 'raxml_bl_unfiltered',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                'raxml_exe'             => $self->o('raxml_exe'),
                'treebest_exe'          => $self->o('treebest_exe'),
                'input_clusterset_id'   => 'treebest',
                'output_clusterset_id'  => $self->o('use_notung') ? 'raxml_bl' : 'default',
                'remove_columns'        => 0,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name => '4Gb_job',
            -flow_into  => {
                $self->o('use_notung') ? 1 : 999 => [ 'notung' ],
                2 => [ 'promote_treebest_tree' ],
                -1 => [ 'raxml_bl_unfiltered_himem' ],
             },
        },

        {   -logic_name => 'raxml_bl_unfiltered_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                'raxml_exe'             => $self->o('raxml_exe'),
                'treebest_exe'          => $self->o('treebest_exe'),
                'input_clusterset_id'   => 'treebest',
                'output_clusterset_id'  => $self->o('use_notung') ? 'raxml_bl' : 'default',
                'remove_columns'        => 0,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name => '16Gb_job',
            -flow_into  => {
                $self->o('use_notung') ? 1 : 999 => [ 'notung' ],
                2 => [ 'promote_treebest_tree' ],
             },
        },

        {   -logic_name => 'promote_treebest_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyLocalTree',
            -parameters => {
                'treebest_exe'          => $self->o('treebest_exe'),
                'input_clusterset_id'   => 'treebest',
                'output_clusterset_id'  => 'default',
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name => '8Gb_job',
        },


        {   -logic_name => 'raxml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                'raxml_exe'                 => $self->o('raxml_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'output_clusterset_id'      => $self->o('use_notung') ? 'raxml' : 'default',
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '1Gb_job',
            -flow_into  => {
                -1 => [ 'raxml_himem' ],
                2 =>  [ 'treebest' ],     # This event is triggered if there are 2 or 3 genes in the tree
                $self->o('use_notung') ? 1 : 999 => [ 'notung' ],
            }
        },

        {   -logic_name => 'raxml_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                'raxml_exe'                 => $self->o('raxml_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'output_clusterset_id'      => $self->o('use_notung') ? 'raxml' : 'default',
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '4Gb_job',
            -flow_into  => $self->o('use_notung') ? [ 'notung' ] : [],
        },

        {   -logic_name => 'notung',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                'notung_jar'                => $self->o('notung_jar'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'label'                     => 'binary',
                'input_clusterset_id'       => $self->o('use_raxml') ? 'raxml' : 'raxml_bl',
                'output_clusterset_id'      => 'notung',
                'notung_memory'             => 1500,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -rc_name        => '2Gb_job',
            -flow_into      => {
                1  => [ 'raxml_bl' ],
                -1 => [ 'notung_himem' ],
            },
        },

        {   -logic_name => 'notung_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                'notung_jar'            => $self->o('notung_jar'),
                'treebest_exe'          => $self->o('treebest_exe'),
                'label'                 => 'binary',
                'input_clusterset_id'   => $self->o('use_raxml') ? 'raxml' : 'raxml_bl',
                'output_clusterset_id'  => 'notung',
                'notung_memory'         => 7000,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -rc_name        => '8Gb_job',
            -flow_into      => [ 'raxml_bl_himem' ],
        },

        {   -logic_name => 'raxml_bl',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                'raxml_exe'                 => $self->o('raxml_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'input_clusterset_id'       => 'notung',
                'escape_branch'             => -1,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '1Gb_job',
            -flow_into  => {
                -1 => [ 'raxml_bl_himem' ],
            }
        },

        {   -logic_name => 'raxml_bl_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                'raxml_exe'                 => $self->o('raxml_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'input_clusterset_id'       => 'notung',
                'escape_branch'             => -1,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '4Gb_job',
        },

        {   -logic_name         => 'hc_alignment_post_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -flow_into          => [ 'hc_tree_structure' ],
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_tree_structure',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_structure',
            },
            -flow_into          => [ 'homology_entry_point' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'homology_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'ortho_tree', 'other_tree_factory' ],
                'A->1'  => [ 'finalize_entry_point' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'other_tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE ref_root_id = #gene_tree_id#',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                 2 => [ 'hc_other_tree_structure' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name => 'ortho_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'homoeologous_genome_dbs' => $self->o('homoeologous_genome_dbs'),
            },
            -hive_capacity  => $self->o('ortho_tree_capacity'),
            -rc_name        => '250Mb_job',
            -flow_into      => {
                1   => [ 'hc_tree_attributes', 'hc_tree_homologies' ],
                -1  => 'ortho_tree_himem',
            },
        },

        {   -logic_name => 'ortho_tree_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'homoeologous_genome_dbs' => $self->o('homoeologous_genome_dbs'),
            },
            -hive_capacity  => $self->o('ortho_tree_capacity'),
            -rc_name        => '4Gb_job',
            -flow_into      => [ 'hc_tree_attributes', 'hc_tree_homologies' ],
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
            -batch_size    => 5,
            -rc_name       => '500Mb_job',
            -flow_into     => {
                -1 => [ 'ktreedist_himem' ],
            },
        },

        {   -logic_name    => 'ktreedist_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters    => {
                               'treebest_exe'  => $self->o('treebest_exe'),
                               'ktreedist_exe' => $self->o('ktreedist_exe'),
                              },
            -hive_capacity => $self->o('ktreedist_capacity'),
            -rc_name       => '2Gb_job',
        },

        {   -logic_name         => 'hc_other_tree_structure',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_structure',
            },
            -flow_into          => [ 'ortho_tree_annot' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'ortho_tree_annot',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'store_homologies'  => 0,
                'homoeologous_genome_dbs' => $self->o('homoeologous_genome_dbs'),
            },
            -hive_capacity  => $self->o('ortho_tree_annot_capacity'),
            -rc_name        => '250Mb_job',
            -batch_size     => 20,
            -flow_into      => {
                1   => [ 'hc_tree_attributes' ],
                -1  => [ 'ortho_tree_annot_himem' ],
            },
        },

        {   -logic_name => 'ortho_tree_annot_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'store_homologies'  => 0,
                'homoeologous_genome_dbs' => $self->o('homoeologous_genome_dbs'),
            },
            -hive_capacity  => $self->o('ortho_tree_annot_capacity'),
            -rc_name        => '4Gb_job',
            -flow_into      => [ 'hc_tree_attributes' ],
        },

        {   -logic_name => 'finalize_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [ 'ktreedist', 'build_HMM_aa', 'build_HMM_cds' ],
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'build_HMM_aa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'buildhmm_exe'      => $self->o('buildhmm_exe'),
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -priority       => -20,
            -rc_name        => '250Mb_job',
            -flow_into      => {
                -1  => 'build_HMM_aa_himem'
            },
        },

        {   -logic_name     => 'build_HMM_aa_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'buildhmm_exe'  => $self->o('buildhmm_exe'),
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -priority       => -20,
            -rc_name        => '1Gb_job',
        },

        {   -logic_name => 'build_HMM_cds',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'cdna'              => 1,
                'buildhmm_exe'      => $self->o('buildhmm_exe'),
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -priority       => -20,
            -rc_name        => '500Mb_job',
            -flow_into      => {
                -1  => 'build_HMM_cds_himem'
            },
        },

        {   -logic_name     => 'build_HMM_cds_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'cdna'          => 1,
                'buildhmm_exe'  => $self->o('buildhmm_exe'),
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -priority       => -20,
            -rc_name        => '2Gb_job',
        },

# ---------------------------------------------[Quick tree break steps]-----------------------------------------------------------------------

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
                'sql'         => 'INSERT INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL AND root_id = #gene_tree_id#',
            },
            -analysis_capacity => 1,
            -meadow_type    => 'LOCAL',
            -flow_into      => [ 'alignment_entry_point' ],
        },



# -------------------------------------------[name mapping step]---------------------------------------------------------------------

        {
            -logic_name => 'stable_id_mapping',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters => {
                'prev_rel_db'   => '#reuse_db#',
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

1;

