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

        'species_tree_input_file' => '',    # a non-empty value will force the loader to take the data from the file

    };
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [ ]; # force this to be a top-up config
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name    => 'test_make_species_tree3',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
            },
            -input_ids     => [
                { 'species_tree_input_file' => $self->o('species_tree_input_file') },
            ],
            -flow_into  => {
                3 => { 'mysql:////meta' => { 'meta_key' => 'test_species_tree3', 'meta_value' => '#species_tree_string#' } },
            },
        },
        
    ];
}

1;

