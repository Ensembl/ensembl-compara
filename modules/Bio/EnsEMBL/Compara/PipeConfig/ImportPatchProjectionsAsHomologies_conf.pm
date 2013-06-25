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
        'release'         => '71',          # current ensembl release number
        'rel_suffix'      => '',            # an empty string by default, a letter otherwise

        'rel_with_suffix' => $self->o('release').$self->o('rel_suffix'),
        'pipeline_name'   => 'homology_projections_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        # GenomeDB names of the species with patches
        'patch_species'   => ['homo_sapiens', 'mus_musculus'],

        # URLs of other pipelines (from which we inherit the members and sequences)
        'family_db'       => 'mysql://ensro@compara4/lg4_compara_families_71',
        'ncrnatrees_db'   => 'mysql://ensro@compara2/mp12_compara_nctrees_71',

    };
}



sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'patch_import'  => { 'LSF' => '-C0 -M250000 -R"select[mem>250] rusage[mem=250]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'       => $self->o('family_db'),
                'inputlist'     => [ 'genome_db', 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_node', 'ncbi_taxa_name', 'sequence', 'member' ],
                'column_names'  => [ 'table' ],
            },
            -input_ids => [ { }, ],
            -flow_into => {
                '2->A' => [ 'copy_table_from_family_db'  ],
                'A->1' => [ 'add_ncrna_sequences' ],
            },
        },

        {   -logic_name    => 'copy_table_from_family_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('family_db'),
                'mode'          => 'overwrite',
            },
        },

        {   -logic_name    => 'add_ncrna_sequences',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('ncrnatrees_db'),
                'table'         => 'sequence',
                'mode'          => 'topup',
            },
            -flow_into     => [ 'add_ncrna_members' ],
        },

        {   -logic_name    => 'add_ncrna_members',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('ncrnatrees_db'),
                'table'         => 'member',
                'mode'          => 'topup',
            },
            -flow_into     => [ 'offset_tables' ],
        },

        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE sequence       AUTO_INCREMENT=300000001',
                    'ALTER TABLE member         AUTO_INCREMENT=300000001',
                    'ALTER TABLE homology       AUTO_INCREMENT=300000001',

                    # These homologies are not linked to gene trees. We need to tweak the schema
                    'ALTER TABLE homology       MODIFY COLUMN ancestor_node_id int(10) unsigned',
                    'ALTER TABLE homology       MODIFY COLUMN tree_node_id     int(10) unsigned',
                    'ALTER TABLE homology       DROP FOREIGN KEY homology_ibfk_3',
                    'ALTER TABLE homology       DROP FOREIGN KEY homology_ibfk_2',
                ],
            },
            -flow_into => [ 'species_factory' ],
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

    ];
}

1;


