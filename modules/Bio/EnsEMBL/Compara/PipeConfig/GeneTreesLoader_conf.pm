
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::GeneTreesLoader_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::GeneTreesLoader_conf -password <your_password>

=head1 DESCRIPTION  

    This is a test of certain tricks needed for loading GeneTrees pipeline

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneTreesLoader_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'release'   => 59,

        'pipeline_name' => 'gene_tree_loader',

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                        # a rule where a previously undefined parameter is used (which makes either of them obligatory)
            -dbname => $ENV{USER}.'_'.$self->o('pipeline_name'),    # a rule where a previously defined parameter is used (which makes both of them optional)
        },

        'reg1' => {
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'reg2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'reg3' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        master_db => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        }
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'create_species_sets',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  "INSERT INTO species_set VALUES ()",   # inserts a dummy pair (auto_increment++, 0) into the table
                            "INSERT INTO species_set VALUES ()",   # inserts another dummy pair (auto_increment++, 0) into the table
                            "DELETE FROM species_set WHERE species_set_id IN (#_insert_id_0#, #_insert_id_1#)", # will delete the rows previously inserted, but keep the auto_increment
                ],
            },
            -input_ids  => [
                { },
            ],
            -flow_into => {
                2 => { 'load_genomedb_factory'    => { 'total_ss' => '#_insert_id_0#', 'reuse_ss' => '#_insert_id_1#' } },
            },
            -rc_id => 1,
        },

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'           => $self->o('master_db'),
                'inputquery'        => 'SELECT genome_db_id, name, assembly FROM genome_db WHERE taxon_id AND assembly_default',
                'fan_branch_code'   => 2,
                'input_id'          => { 'genome_db_id' => '#_start_0#', 'species_name' => '#_start_1#', 'assembly_name' => '#_start_2#', 'total_ss' => '#total_ss#', 'reuse_ss' => '#reuse_ss#' },   
            },
            -flow_into => {
                2 => [ 'load_one_genomedb' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'load_one_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => [ $self->o('reg1'), $self->o('reg2') ],
            },
            -flow_into => {
                1 => {  'mysql:////species_set' => { 'genome_db_id' => '#genome_db_id#', 'species_set_id' => '#total_ss#' },
                        'check_reusability'     => { 'genome_db_id' => '#genome_db_id#', 'reuse_ss' => '#reuse_ss#'},
                },
            },
        },

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTreesCheckGenomedbReusability',
            -parameters => {
                'registry_dbs'  => [ $self->o('reg3') ],
                'release'       => $self->o('release'),
            },
            -flow_into => {
                2 => {  'mysql:////species_set' => { 'genome_db_id' => '#genome_db_id#', 'species_set_id' => '#reuse_ss#' } },
            }
        }
    ];
}

1;

