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

Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The pipeline will create a database with all the (gene|seq)_members of all current species in the
given "compara_master" database.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # names of species we don't want to reuse this time
        #'do_not_reuse_list'     => [ 'homo_sapiens', 'mus_musculus', 'rattus_norvegicus', 'mus_spretus_spreteij', 'danio_rerio', 'sus_scrofa' ],
        'do_not_reuse_list'     => [ ],

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,
        'allow_missing_coordinates' => 0,
        'allow_missing_cds_seqs'    => 0,
        # Genes with these logic_names will be ignored from the pipeline.
        # Format is { genome_db_id (or name) => [ 'logic_name1', 'logic_name2', ... ] }
        # An empty string can also be used as the key to define logic_names excluded from *all* species
        'exclude_gene_analysis'     => {},
        # Store protein-coding genes
        'store_coding'              => 1,
        # Store ncRNA genes
        'store_ncrna'               => 1,
        # Store other genes
        'store_others'              => 1,

    #load uniprot members for family pipeline
        'load_uniprot_members'      => 0,
        'work_dir'        => $self->o('pipeline_dir'),
        'uniprot_dir'     => $self->o('work_dir').'/uniprot',
        'uniprot_rel_url' => 'https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/reldate.txt',
        'uniprot_ftp_url' => 'https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/uniprot_#uniprot_source#_#tax_div#.dat.gz',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'hc_capacity'               => 150,
        'loadmembers_capacity'      =>  30,

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => -10,

    # connection parameters to various databases:

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'compara_master',
        'master_db_is_missing_dnafrags' => 0,

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        # 'curr_core_sources_locs'    => [ $self->o('staging_loc') ],
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        'reuse_member_db' => 'compara_prev',

        # By default, do not load non reference sequences and patches for fresh
        # members
        'include_nonreference' => 0,
        'include_patches'      => 0,
        'include_lrg'          => 0,

        # list of species that got an annotation update
        # ... assuming the same person has run both pipelines
        'expected_updates_file' => $self->o('shared_hps_dir') . '/genome_reports/annotation_updates.' . $self->o('division') . '.' . $self->o('ensembl_release') . '.list',
    };
}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    # There must be some species on which to compute trees
    die "There must be some species on which to compute trees"
        if ref $self->o('curr_core_sources_locs') and not scalar(@{$self->o('curr_core_sources_locs')})
        and ref $self->o('curr_file_sources_locs') and not scalar(@{$self->o('curr_file_sources_locs')});

    # The master db must be defined to allow mapping stable_ids and checking species for reuse
    # ...but note that the master database is not required in the current QfO SOP.
    #die "No master database provided" if not $self->o('master_db');
    die "Species reuse is only possible with a master database" if $self->o('reuse_member_db') and not $self->o('master_db');
    die "Species reuse is only possible with some previous core databases" if $self->o('reuse_member_db') and ref $self->o('prev_core_sources_locs') and not scalar(@{$self->o('prev_core_sources_locs')});
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        # Database connection
        'master_db'             => $self->o('master_db'),
        'reuse_member_db'       => $self->o('reuse_member_db'),
        'load_uniprot_members'  => $self->o('load_uniprot_members'),
        'work_dir'              => $self->o('work_dir'),
        'uniprot_dir'           => $self->o('uniprot_dir'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
            -max_retry_count    => 1,
    );

    return [

# ---------------------------------------------[backbone]--------------------------------------------------------------------------------

        {   -logic_name => 'check_versions_match',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -input_ids  => [ { } ],
            -flow_into  => WHEN(
                    '#reuse_member_db#' => 'check_reuse_db_is_patched',
                    ELSE 'copy_ncbi_tables_factory',
                    ),
        },

        {   -logic_name => 'copy_ncbi_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],
                'column_names' => [ 'table' ],
            },
            -flow_into => {
                '2->A' => [ 'copy_table_from_master'  ],
                'A->1' => WHEN(
                    '#master_db#' => 'offset_tables',
                    ELSE 'load_all_genomedbs_from_registry',
                ),
            },
        },

        {   -logic_name    => 'copy_table_from_master',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#master_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        # CreateReuseSpeciesSets/PrepareSpeciesSetsMLSS may want to create new
        # entries. We need to make sure they don't collide with the master database
        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE species_set_header      AUTO_INCREMENT=10000001',
                ],
            },
            -flow_into      => [ 'load_genomedb_factory' ],
        },

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'all_current'       => 1,
                'extra_parameters'  => [ 'locator' ],
            },
            -rc_name => '2Gb_job',
            -flow_into => {
                '2->A' => {
                    'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' },
                },
                'A->1' => [ 'create_reuse_ss' ],
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            -rc_name => '2Gb_job',
            -flow_into  => [ 'check_reusability' ],
            -hive_capacity => $self->o('loadmembers_capacity'),
            -batch_size => $self->o('loadmembers_capacity'),    # Simple heuristic
            -max_retry_count => 2,
        },

        {   -logic_name => 'load_all_genomedbs_from_registry',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadAllGenomeDBsFromRegistry',
            -parameters => {
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            # FIXME: need a factory to check reuse of all species
            -flow_into => [ 'create_reuse_ss' ],
        },
# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckMembersReusability',
            -parameters => {
                # 'registry_dbs'      => $self->o('prev_core_sources_locs'),
                'do_not_reuse_list' => $self->o('do_not_reuse_list'),
                'reuse_db'          => '#reuse_member_db#',
                'store_coding'      => $self->o('store_coding'),
                'store_ncrna'       => $self->o('store_ncrna'),
                'store_others'      => $self->o('store_others'),
                'include_lrg'       => $self->o('include_lrg'),
                'include_patches'   => $self->o('include_patches'),
                'include_nonreference' => $self->o('include_nonreference'),
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
            -rc_name => '2Gb_job',
            -flow_into => {
                2 => '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
                3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
            },
        },

        {   -logic_name => 'create_reuse_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateReuseSpeciesSets',
            -rc_name    => '2Gb_job',
            -flow_into  => [ 'compare_non_reused_genome_list' ],
        },

        {   -logic_name => 'compare_non_reused_genome_list',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::CompareNonReusedGenomeList',
            -parameters => {
                'expected_updates_file' => $self->o('expected_updates_file'),
                'current_release'       => $self->o('ensembl_release'),
            },
            -flow_into  => [ 'nonpolyploid_genome_reuse_factory' ],
        },

        {   -logic_name => 'check_reuse_db_is_patched',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -parameters => {
                'db_conn'       => '#reuse_member_db#',
            },
            -flow_into  => [ 'copy_ncbi_tables_factory' ],
        },


# ---------------------------------------------[reuse members]-----------------------------------------------------------------------

        {   -logic_name => 'nonpolyploid_genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'species_set_id'    => '#reuse_ss_id#',
                'store_ncrna'       => $self->o('store_ncrna'),
                'store_others'      => $self->o('store_others'),
            },
            -flow_into => {
                '2->A' => [ 'all_table_reuse' ],
                'A->1' => 'polyploid_genome_reuse_factory',
            },
        },

        {   -logic_name => 'polyploid_genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
                'species_set_id'    => '#reuse_ss_id#',
            },
            -flow_into => {
                '2->A' => [ 'component_genome_dbs_move_factory' ],
                'A->1' => [ 'nonpolyploid_genome_load_fresh_factory' ],
            },
        },

        {   -logic_name => 'component_genome_dbs_move_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                '2->A' => {
                    'dnafrag_table_reuse' => { 'source_gdb_id' => '#principal_genome_db_id#', 'target_gdb_id' => '#component_genome_db_id#'}
                },
                'A->1' => [ 'hc_polyploid_genes' ],
            },
        },

        {   -logic_name => 'move_component_genes',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MoveComponentGenes',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => {
                    'hc_members_per_genome' => { 'genome_db_id' => '#target_gdb_id#' },
                },
            },
        },

        {   -logic_name => 'hc_polyploid_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'description'   => 'All the genes of the polyploid species should be moved to the component genomes',
                'query'         => 'SELECT * FROM gene_member WHERE genome_db_id = #genome_db_id#',
            },
            %hc_analysis_params,
        },


        {   -logic_name => 'all_table_reuse',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyMembersByGenomeDB',
            -parameters => {
                'reuse_db'          => '#reuse_member_db#',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'hc_members_per_genome' ],
        },

        {   -logic_name => 'dnafrag_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_member_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #target_gdb_id#',
                'mode'          => 'insertignore',
            },
            -flow_into  => [ 'move_component_genes' ],
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
                allow_ambiguity_codes => $self->o('allow_ambiguity_codes'),
                allow_missing_coordinates   => $self->o('allow_missing_coordinates'),
                allow_missing_cds_seqs      => $self->o('allow_missing_cds_seqs'),
                only_canonical              => 0,
            },
            %hc_analysis_params,
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'nonpolyploid_genome_load_fresh_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
                'extra_parameters'  => [ 'locator' ],
                'species_set_id'    => '#nonreuse_ss_id#',
            },
            -flow_into => {
                '2->A' => WHEN(
                    '(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/) and  #master_db#' => 'copy_dnafrags_from_master',
                    '(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/) and !#master_db#' => 'load_fresh_members_from_db',
                    ELSE 'load_fresh_members_from_file',
                ),
                'A->1' => [ 'polyploid_genome_load_fresh_factory' ],
            },
        },

        {   -logic_name => 'polyploid_genome_load_fresh_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
                'extra_parameters'  => [ 'locator' ],
                'species_set_id'    => '#nonreuse_ss_id#',
            },
            -flow_into => {
                '2->A' => WHEN(
                    # Not all the cases are covered
                    '(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/) and #master_db#' => 'copy_polyploid_dnafrags_from_master',
                    '!(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/)' => 'component_dnafrags_duplicate_factory',
                ),
                'A->1' => [ 'hc_members_globally' ],
            },
        },

        {   -logic_name => 'component_dnafrags_duplicate_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                2 => {
                    'duplicate_component_dnafrags' => { 'source_gdb_id' => '#principal_genome_db_id#', 'target_gdb_id' => '#component_genome_db_id#'}
                },
            },
        },

        {   -logic_name => 'duplicate_component_dnafrags',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [
                    'INSERT INTO dnafrag (length, name, genome_db_id, coord_system_name, is_reference) SELECT length, name, #principal_genome_db_id#, coord_system_name, is_reference FROM dnafrag WHERE genome_db_id = #principal_genome_db_id#',
                ],
            },
            -flow_into  => [ 'hc_component_dnafrags' ],
        },

        {   -logic_name => 'copy_polyploid_dnafrags_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into  => [ 'component_dnafrags_hc_factory' ],
        },

        {   -logic_name => 'component_dnafrags_hc_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                2 => [ 'hc_component_dnafrags' ],
            },
        },

        {   -logic_name => 'hc_component_dnafrags',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'description'   => 'All the component dnafrags must be in the principal genome',
                'query'         => 'SELECT d1.* FROM dnafrag d1 LEFT JOIN dnafrag d2 ON d2.genome_db_id = #principal_genome_db_id# AND d1.name = d2.name WHERE d1.genome_db_id = #component_genome_db_id# AND d2.dnafrag_id IS NULL',
            },
            %hc_analysis_params,
        },

        {   -logic_name => 'copy_dnafrags_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'load_fresh_members_from_db' ],
        },

        {   -logic_name => 'load_fresh_members_from_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'store_related_pep_sequences' => 1,
                'allow_ambiguity_codes'         => $self->o('allow_ambiguity_codes'),
                'find_canonical_translations_for_polymorphic_pseudogene' => 1,
                'store_missing_dnafrags'        => ((not $self->o('master_db')) or $self->o('master_db_is_missing_dnafrags') ? 1 : 0),
                'exclude_gene_analysis'         => $self->o('exclude_gene_analysis'),
                'include_nonreference'          => $self->o('include_nonreference'),
                'include_patches'               => $self->o('include_patches'),
                'include_lrg'                   => $self->o('include_lrg'),
                'store_coding'                  => $self->o('store_coding'),
                'store_ncrna'                   => $self->o('store_ncrna'),
                'store_others'                  => $self->o('store_others'),
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
            -rc_name => '4Gb_job',
            -flow_into => [ 'hc_members_per_genome' ],
        },

        {   -logic_name => 'load_fresh_members_from_file',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembersFromFiles',
            -parameters => {
                'need_cds_seq'  => 1,
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
            -flow_into          => {
                '2->A' => WHEN( '#load_uniprot_members#' => 'save_uniprot_release_date' ),
                'A->1' => [ 'datachecks' ],
            },
        },

        {   -logic_name      => 'datachecks',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks',
            -parameters      => {
                'datacheck_names'  => ['BlankEnums', 'CheckSequenceTable'],
                'work_dir'         => $self->o('work_dir'),
                'history_file'     => '#work_dir#/datacheck.compara_load_members.history.json',
                'output_file'      => '#work_dir#/datacheck.compara_load_members.tap.txt',
                'failures_fatal'   => 1,
                'pdbname'          => $self->o('pipeline_name'),
                'dbtype'           => 'compara',
            },
            -max_retry_count => 0,
        },

# ---------------------------------------------[load UNIPROT members for Family pipeline]------------------------------------------------------------

        {   -logic_name => 'save_uniprot_release_date',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtReleaseVersion',
            -parameters => {
                'uniprot_rel_url'   => $self->o('uniprot_rel_url'),
            },
            -flow_into  => [ 'download_uniprot_factory' ],
        },

        {   -logic_name => 'download_uniprot_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names'    => [ 'uniprot_source', 'tax_div' ],
                'inputlist'       => [
                    [ 'sprot', 'fungi' ],
                    [ 'sprot', 'human' ],
                    [ 'sprot', 'mammals' ],
                    [ 'sprot', 'rodents' ],
                    [ 'sprot', 'vertebrates' ],
                    [ 'sprot', 'invertebrates' ],

                    [ 'trembl',  'fungi' ],
                    [ 'trembl',  'human' ],
                    [ 'trembl',  'mammals' ],
                    [ 'trembl',  'rodents' ],
                    [ 'trembl',  'vertebrates' ],
                    [ 'trembl',  'invertebrates' ],
                ],
            },
            -flow_into => {
                '2' => [ 'download_and_chunk_uniprot' ],
            },
        },

        {   -logic_name    => 'download_and_chunk_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::DownloadAndChunkUniProtFile',
            -parameters => {
                'uniprot_ftp_url'   => $self->o('uniprot_ftp_url'),
            },
            -flow_into => {
                2 => { 'load_uniprot' => INPUT_PLUS() },
            },
        },
        
        {   -logic_name    => 'load_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries',
            -parameters => {
                'seq_loader_name'   => 'file', # {'pfetch' x 20} takes 1.3h; {'mfetch' x 7} takes 2.15h; {'pfetch' x 14} takes 3.5h; {'pfetch' x 30} takes 3h;
            },
            -analysis_capacity => 5,
            -batch_size    => 100,
            -rc_name => '2Gb_job',
        },

    ];
}

1;
