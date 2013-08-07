=pod 

=head1 NAME

    Bio::EnsEMBL::Compara::PipeConfig::ImportPatchProjectionsAsHomologies_conf

=head1 DESCRIPTION  

    The PipeConfig file for the pipeline that imports projections from reference
    sequences to patches as homologies.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::ImportPatchProjectionsAsHomologies_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'host'            => 'compara3',    # where the pipeline database will be created
        'release'         => '73',          # current ensembl release number
        'rel_suffix'      => '',            # an empty string by default, a letter otherwise

        'rel_with_suffix' => $self->o('release').$self->o('rel_suffix'),
        'pipeline_name'   => 'homology_projections_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        # GenomeDB names of the species with patches
        'patch_species'   => ['homo_sapiens', 'mus_musculus'],

        # URLs of other databases (from which we inherit the members and sequences, and base objects)
        'master_db'       => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
        'family_db'       => 'mysql://ensro@compara2/lg4_compara_families_73',
        'ncrnatrees_db'   => 'mysql://ensro@compara3/mp12_compara_nctrees_73',

    };
}



sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '500Mb_job'    => {'LSF' => '-C0 -M500000   -R"select[mem>500]   rusage[mem=500]"' },
        'patch_import'  => { 'LSF' => '-C0 -M250000 -R"select[mem>250] rusage[mem=250]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'copy_from_master_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => [ 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_node', 'ncbi_taxa_name' ],
                'column_names'  => [ 'table' ],
            },
            -input_ids => [ { }, ],
            -flow_into => {
                '1->A' => [ 'copy_from_familydb_factory' ],
                '2->A' => [ 'copy_table_from_master_db'  ],
                'A->1' => [ 'offset_tables' ],
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
                'inputlist'     => [ 'genome_db', 'sequence', 'member' ],
                'column_names'  => [ 'table' ],
            },
            -flow_into => {
                2 => [ 'copy_table_from_family_db'  ],
            },
        },

        {   -logic_name    => 'copy_table_from_family_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('family_db'),
                'mode'          => 'overwrite',
            },
            -flow_into     => [ 'topup_table_from_ncrna_db' ],
        },

        {   -logic_name    => 'topup_table_from_ncrna_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('ncrnatrees_db'),
                'mode'          => 'topup',
            },
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
            -flow_into => [ 'species_factory', 'member_display_labels_factory' ],
        },

        {   -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'         => $self->o('patch_species'),
                'column_names'      => ['species'],
            },
            -flow_into => {
                2 => [ 'import_projections_as_homologies' ],
            },
        },

        {   -logic_name => 'import_projections_as_homologies',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ImportPatchProjectionsAsHomologies',
            -rc_name    => 'patch_import',
        },

        {
            -logic_name => 'member_display_labels_factory',
            -module => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT genome_db_id FROM genome_db',
            },
            -flow_into => {
                2 => { 'update_member_display_labels' => { genome_db_ids => ['#genome_db_id#'] } },
            },
            -meadow_type    => 'LOCAL',
        },

        {
            -logic_name => 'update_member_display_labels',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
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
            },
            -rc_name => '500Mb_job',
        },

    ];
}

1;


