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

=pod 

=head1 NAME

    Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf

=head1 DESCRIPTION  

    The PipeConfig file for the pipeline that imports alternative alleles
    as homologies.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'host'            => 'compara1',    # where the pipeline database will be created

        'pipeline_name'   => 'homology_projections_'.$self->o('ensembl_release'),   # also used to differentiate submitted processes

        # URLs of other databases (from which we inherit the members and sequences, and base objects)
        'master_db'       => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
        'family_db'       => 'mysql://ensro@compara2/lg4_compara_families_75',
        'ncrnatrees_db'   => 'mysql://ensro@compara4/mp12_compara_nctrees_75',

        # Tables to copy and merge
        'tables_from_master'    => [ 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_node', 'ncbi_taxa_name' ],
        'tables_to_merge'       => [ 'member', 'sequence' ],
        'tables_to_copy'        => [ 'genome_db' ],
    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '500Mb_job'    => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
        'patch_import'  => { 'LSF' => '-C0 -M250 -R"select[mem>250] rusage[mem=250]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'pipeline_start_analysis',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids => [ { }, ],
            -flow_into => {
                '1->A' => [ 'copy_from_master_factory', 'copy_from_familydb_factory', 'merge_tables_factory' ],
                'A->1' => [ 'offset_tables' ],
            },
        },

        {   -logic_name => 'copy_from_master_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => $self->o('tables_from_master'),
                'column_names'  => [ 'table' ],
            },
            -flow_into => {
                2 => [ 'copy_table_from_master_db'  ],
            },
        },

        {   -logic_name    => 'copy_table_from_master_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('master_db'),
                'mode'          => 'topup',
            },
        },

        {   -logic_name => 'copy_from_familydb_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => $self->o('tables_to_copy'),
                'column_names'  => [ 'table' ],
            },
            -flow_into => {
                2 => [ 'topup_table_from_family_db'  ],
            },
        },

        {   -logic_name => 'merge_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => $self->o('tables_to_merge'),
                'column_names'  => [ 'table' ],
            },
            -flow_into => {
                2 => [ 'topup_table_from_ncrna_db' ],
            },
        },

 
        {   -logic_name    => 'topup_table_from_family_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('family_db'),
                'mode'          => 'topup',
            },
        },

        {   -logic_name    => 'topup_table_from_ncrna_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('ncrnatrees_db'),
                'mode'          => 'topup',
            },
            -flow_into      => [ 'topup_table_from_family_db' ],
        },


        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE sequence       AUTO_INCREMENT=300000001',
                    'ALTER TABLE member         AUTO_INCREMENT=300000001',
                    'ALTER TABLE homology       AUTO_INCREMENT=300000001',
                ],
            },
            -flow_into => [ 'species_factory' ],
        },

        {
            -logic_name => 'species_factory',
            -module => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT genome_db_id FROM genome_db',
            },
            -flow_into => {
                2   => [ 'altallegroup_factory' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {
            -logic_name => 'altallegroup_factory',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'     => [ 'compara_dba', 'get_GenomeDBAdaptor', ['fetch_by_dbID', '#genome_db_id#'], 'db_adaptor', 'get_AltAlleleGroupAdaptor', 'fetch_all' ],
                'column_names2getters'  => { 'alt_allele_group_id' => 'dbID' },
            },
            -flow_into => {
                '2->A' => [ 'import_altalleles_as_homologies' ],
                'A->1' => [ 'update_member_display_labels' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name => 'import_altalleles_as_homologies',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies',
            -parameters => {
                'mafft_home' => '/software/ensembl/compara/mafft-7.113/',
            },
            -rc_name    => 'patch_import',
        },

        {
            -logic_name => 'update_member_display_labels',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -flow_into => [ 'update_member_descriptions' ],
            -rc_name => '500Mb_job',
        },

        {
            -logic_name => 'update_member_descriptions',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'description',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -rc_name => '500Mb_job',
        },

    ];
}

1;


