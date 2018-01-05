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

Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf

=head1 DESCRIPTION

    The pipeline will create a database with all the (gene|seq)_members of a collection of species

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

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

    # parameters inherited from EnsemblGeneric_conf and very unlikely to be redefined:
        # It defaults to Bio::EnsEMBL::ApiVersion::software_version()
        # 'ensembl_release'       => 68,

    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        # Change this one to allow multiple runs
        #'rel_suffix'            => 'b',
        #'collection'            => 'ensembl',

    # custom pipeline name, in case you don't like the default one
        # 'rel_with_suffix' is the concatenation of 'ensembl_release' and 'rel_suffix'
        #'pipeline_name'        => 'load_members'.$self->o('rel_with_suffix'),

        # names of species we don't want to reuse this time
        #'do_not_reuse_list'     => [ 'homo_sapiens', 'mus_musculus', 'rattus_norvegicus', 'mus_spretus_spreteij', 'danio_rerio', 'sus_scrofa' ],
        'do_not_reuse_list'     => [ ],

    # "Member" parameters:
        'allow_ambiguity_codes'     => 0,
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

    # hive_capacity values for some analyses:
        #'reuse_capacity'            =>   3,
        #'hc_capacity'               => 150,
        #'loadmembers_capacity'      =>  30,

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => -10,

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        #'host'  => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        #'port'  => 4522,

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master',
        'master_db_is_missing_dnafrags' => 0,

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        #'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],
        #'curr_core_registry'        => "registry.conf",
        'curr_core_registry'        => undef,
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        #'prev_core_sources_locs'   => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        #'prev_core_sources_locs'   => [ ],

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        #'reuse_member_db' => '',
        #'reuse_member_db' => 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_89',

        # Production database (for the biotypes)
        #'production_db_url'     => 'mysql://anonymous@ensembldb.ensembl.org:5306/ensembl_production_89',
        #'production_db_url'     => 'mysql://ensro@mysql-ens-sta-1:4519/ensembl_production',
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '250Mb_job'    => {'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },

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
    die "The master dabase must be defined with a collection" if $self->o('master_db') and not $self->o('collection');
    die "collection can not be defined in the absence of a master dabase" if $self->o('collection') and not $self->o('master_db');
    die "Species reuse is only possible with a master database" if $self->o('reuse_member_db') and not $self->o('master_db');
    die "Species reuse is only possible with some previous core databases" if $self->o('reuse_member_db') and ref $self->o('prev_core_sources_locs') and not scalar(@{$self->o('prev_core_sources_locs')});

    return $self->SUPER::pipeline_create_commands;  # Nothing more than what the parent class wants
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        # Database connection
        'master_db'             => $self->o('master_db'),
        'reuse_member_db'       => $self->o('reuse_member_db'),
        'production_db_url'     => $self->o('production_db_url'),
    };
}


sub pipeline_analyses {
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
                    '#master_db#' => 'load_genomedb_factory',
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

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'collection_name'   => $self->o('collection'),    # takes precedence over "all_current" below
                'all_current'       => 1,
                'extra_parameters'  => [ 'locator' ],
            },
            -rc_name => '4Gb_job',
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
                'registry_conf_file'  => $self->o('curr_core_registry'),
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            -rc_name => '1Gb_job',
            -flow_into  => [ 'check_reusability' ],
            -hive_capacity => $self->o('loadmembers_capacity'),
            -batch_size => $self->o('loadmembers_capacity'),    # Simple heuristic
            -max_retry_count => 2,
        },

        {   -logic_name => 'load_all_genomedbs_from_registry',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadAllGenomeDBsFromRegistry',
            -parameters => {
                'registry_conf_file'  => $self->o('curr_core_registry'),
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            # FIXME: need a factory to check reuse of all species
            -flow_into => [ 'create_reuse_ss' ],
        },
# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
                'registry_dbs'      => $self->o('prev_core_sources_locs'),
                'do_not_reuse_list' => $self->o('do_not_reuse_list'),
                'reuse_db'          => '#reuse_member_db#',
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
            -rc_name => '1Gb_job',
            -flow_into => {
                2 => '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
                3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
            },
        },

        {   -logic_name => 'create_reuse_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateReuseSpeciesSets',
            -rc_name => '2Gb_job',
            -flow_into => [ 'nonpolyploid_genome_reuse_factory' ],
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
            },
            -flow_into => {
                '2->A' => [ 'all_table_reuse' ],
                'A->1' => [ 'polyploid_genome_reuse_factory' ],
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
            -rc_name => '250Mb_job',
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
                'include_nonreference'          => 1,
                'include_patches'               => 1,
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
        },

    ];
}

1;

