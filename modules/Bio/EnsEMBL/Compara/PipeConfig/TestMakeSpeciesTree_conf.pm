## A configuration file to test MakeSpeciesTree runnable


package Bio::EnsEMBL::Compara::PipeConfig::TestMakeSpeciesTree_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_db' => {
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'lg4_compara_homology_61h',
        },

        'master_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'sf5_ensembl_compara_master',
        },

    };
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [ ]; # force this to be a top-up config
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name    => 'test_make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                # 'master_db'   => $self->o('master_db'),
            },
            -input_ids     => [
                { },
            ],
            -flow_into  => {
                3 => { 'mysql:////meta' => { 'meta_key' => 'test_species_tree', 'meta_value' => '#species_tree_string#' } },
            },
        },
        
    ];
}

1;

