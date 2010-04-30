## Generic configuration module for all Compara pipelines

package Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => 'compara_generic',
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},    # inheriting database and hive table creation

            # standard and pipeline Compara tables:
        'mysql '.$self->dbconn_2_mysql('pipeline_db', 1).' <'.$self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/table.sql',
        'mysql '.$self->dbconn_2_mysql('pipeline_db', 1).' <'.$self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/pipeline-tables.sql',
                    
    ];
}

1;

