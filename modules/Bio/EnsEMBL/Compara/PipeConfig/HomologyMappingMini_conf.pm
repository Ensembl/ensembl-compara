package Bio::Ensembl::Compara::PipeConfig::HomologyMappingMini_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        }
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
            @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
	'compara_db' => $self->o('compara_db'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
	    {   -logic_name => 'id_map_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -input_ids => [{
                'methods'   => {
                    'ENSEMBL_ORTHOLOGUES'   => 2,
                    'ENSEMBL_PSEUDOGENES_ORTHOLOGUES' => 2,
                    },
            }],
            -flow_into => {
                2 => [ 'mlss_id_mapping' ],
            },
        },

        {   -logic_name => 'mlss_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDMapping',
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
            -flow_into => { 1 => { 'homology_id_mapping' => INPUT_PLUS() } },
        },

        {   -logic_name => 'homology_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -flow_into  => {
                -1 => [ 'homology_id_mapping_himem' ],
            },
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
        },

        {   -logic_name => 'homology_id_mapping_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
        },
    ];
}

1;
