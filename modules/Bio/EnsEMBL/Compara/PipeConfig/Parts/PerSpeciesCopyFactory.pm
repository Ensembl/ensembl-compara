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

Bio::EnsEMBL::Compara::PipeConfig::Parts::PerSpeciesCopyFactory

=head1 DESCRIPTION

    This is a partial PipeConfig for creating and copying independent
    species-specific compara databases

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::PerSpeciesCopyFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

sub pipeline_analyses_create_and_copy_per_species_db {
    my ($self) = @_;

    return [

        {   -logic_name => 'create_db_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesListFactory',
            -flow_into  => [ 'create_per_species_db' ],
        },

        {   -logic_name => 'create_per_species_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::NewPerSpeciesComparaDB',
            -parameters => {
                'curr_release' => $self->o('rel_with_suffix'),
                'db_cmd_path'  => $self->o('db_cmd_path'),
                'schema_file'  => $self->o('schema_file'),
            },
            #-flow_into  => [ 'copy_species_db' ],
        },

    ];
}

1;
