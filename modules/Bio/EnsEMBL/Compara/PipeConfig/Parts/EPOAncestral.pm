=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAncestral

=head1 DESCRIPTION

This is a partial PipeConfig for the creation of a new ancestral database
required to compute an EPO MSA.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAncestral;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  # For WHEN and INPUT_PLUS


sub pipeline_analyses_epo_ancestral {
    my ($self) = @_;
    return [
        {   -logic_name => 'drop_ancestral_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'db_conn'       => '#ancestral_db#',
                'input_query'   => 'DROP DATABASE IF EXISTS',
            },
            -flow_into  => [ 'create_ancestral_db' ],
        },
        {   -logic_name => 'create_ancestral_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'db_conn'       => '#ancestral_db#',
                'input_query'   => 'CREATE DATABASE',
            },
            -flow_into  => [ 'create_tables_in_ancestral_db' ],
        },
        {   -logic_name => 'create_tables_in_ancestral_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'db_conn'       => '#ancestral_db#',
                'input_file'    => $self->o('core_schema_sql'),
            },
            -flow_into  => [ 'store_ancestral_species_name' ],
        },
        {   -logic_name => 'store_ancestral_species_name',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn'   => '#ancestral_db#',
                'sql'       => [
                    'INSERT INTO meta (meta_key, meta_value) VALUES ("species.production_name", "' . $self->o('ancestral_sequences_name') . '")',
                    'INSERT INTO meta (meta_key, meta_value) VALUES ("species.display_name", "' . $self->o('ancestral_sequences_display_name') . '")',
                ],
            },
            -flow_into  => [ 'find_ancestral_seq_gdb' ],
        },
        {   -logic_name => 'find_ancestral_seq_gdb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'    => '#master_db#',
                'call_list'     => [ 'compara_dba', 'get_GenomeDBAdaptor', ['fetch_by_name_assembly', $self->o('ancestral_sequences_name')] ],
                'column_names2getters'  => { 'master_dbID' => 'dbID' },
            },
            -flow_into  => {
                2   => [ 'store_ancestral_seq_gdb' ],
            },
        },
        {   -logic_name => 'store_ancestral_seq_gdb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'locator'   => '#ancestral_db#',
            },
        },
    ];
}


1;
