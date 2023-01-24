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

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

sub pipeline_analyses_create_and_copy_per_species_db {
    my ($self) = @_;

    my %dc_parameters = (
        'datacheck_groups' => $self->o('dc_compara_grp'),
        'db_type'          => $self->o('db_type'),
        'old_server_uri'   => [$self->o('compara_db')],
        'registry_file'    => undef,
    );

    return [

    { -logic_name => 'create_db_factory',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesListFactory',
      -flow_into  => [ 'create_per_species_db' ],
    },

    { -logic_name => 'create_per_species_db',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::NewPerSpeciesComparaDB',
      -parameters => {
                'curr_release' => $self->o('ensembl_release'),
                'db_cmd_path'  => $self->o('db_cmd_path'),
                'schema_file'  => $self->o('schema_file'),
                'homology_host' => $self->o('homology_host'),
            },
      -flow_into => {
                '2->A'  => { 'copy_per_species_db'  => INPUT_PLUS() },
                'A->2'  => { 'datacheck_factory' => { 'compara_db' => '#per_species_db#', %dc_parameters } },
            },
    },

    { -logic_name => 'copy_per_species_db',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::CopyPerSpeciesComparaDB',
      -parameters => {
                'program'    => $self->o('copy_program'),
                'table_list' => $self->o('table_list'),
                'skip_dna'   => $self->o('skip_dna'),
            },
      -hive_capacity => 1,
      -flow_into => {
                1 => [{'record_species_set' => INPUT_PLUS()}, {'production_species_factory'=> INPUT_PLUS()}],
            }
    },

    { -logic_name => 'production_species_factory',
	  -module => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
	  -max_retry_count => 1,
	  -analysis_capacity => 20,
	  -parameters => {
		  'genome_name' => '#genome_name#', 
	      },
	  -flow_into => {
		  '2' => [{'GenomeDirectoryPaths'=> INPUT_PLUS()}],
	      }
	}, 

    { -logic_name        => 'GenomeDirectoryPaths',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::FileDump::DirectoryPaths',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {
                data_category  => 'homology',
                analysis_types => ['Homologies'],
            },
      -flow_into         => {
		    '3' => [{'dump_species_db_to_tsv'=> INPUT_PLUS()}]
            },
    },

    { -logic_name => 'dump_species_db_to_tsv',
	  -module => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpSpeciesDBToTsv',
	  -parameters => {
		  'ref_dbname' => $self->o('ref_dbname'),
	       },
	  -flow_into => {
		  '2' => [{'CompressHomologyTSV'=> INPUT_PLUS()}],
	       },
	  -rc_name       => "4Gb_job",
    },

    { -logic_name => 'CompressHomologyTSV',
	  -module => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	  -max_retry_count   => 1,
	  -analysis_capacity => 10,
	  -batch_size        => 10,
	  -parameters => {
		'cmd' =>  'if [ -s "#filepath#" ]; then gzip -n -f "#filepath#"; fi',
	       },
	  -flow_into         => WHEN('defined #ftp_dir#' => ['Sync']),
	  -rc_name       => "4Gb_job",
	},

    { -logic_name        => 'Sync',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
	      cmd => 'mkdir -p #ftp_dir#; rsync -aLW #output_dir#/ #ftp_dir#',
           },
          -rc_name       => "1Gb_datamover_job",
    },

    { -logic_name => 'record_species_set',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::RecordSpeciesSet',
      -parameters => {
                'species_set_record' => $self->o('species_set_record'),
            },
      -hive_capacity => 1,
    }

    ];
}

1;
