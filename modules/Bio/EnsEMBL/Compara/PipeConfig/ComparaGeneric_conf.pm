## Generic configuration module for all Compara pipelines

package Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'pipeline_name'         => 'compara_generic',
        'compara_innodb_schema' => 1,
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},    # inheriting database and hive table creation

            # Compara 'release' tables will be turned from MyISAM into InnoDB on the fly by default:
        ($self->o('compara_innodb_schema') ? "sed 's/ENGINE=MyISAM/ENGINE=InnoDB/g' " : 'cat ')
            . $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/table.sql | mysql '.$self->dbconn_2_mysql('pipeline_db', 1),

            # Compara 'pipeline' tables are already InnoDB, but can be turned to MyISAM if needed:
        ($self->o('compara_innodb_schema') ? 'cat ' : "sed 's/ENGINE=InnoDB/ENGINE=MyISAM/g' ")
            . $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/pipeline-tables.sql | mysql '.$self->dbconn_2_mysql('pipeline_db', 1),
    ];
}

1;

