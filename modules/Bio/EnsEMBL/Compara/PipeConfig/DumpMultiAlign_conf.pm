=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 SYNOPSIS

Initialise the pipeline on comparaY, grouping the alignment blocks
according to their "homo_sapiens" chromosome

  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --mlss_id 548 --compara_db mysql://ensro@comparaX/msa_db_to_dump --output_dir /path/to/dumps/ --species homo_sapiens --host comparaY

Release 65

epo 6 way: 3.4 hours
epo 12 way: 2.7 hours
mercator/pecan 19 way: 5.5 hours
low coverage epo 35 way: 43 hours (1.8 days)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -driver => 'mysql',
	    -dbname => $self->o('ensembl_release'),
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -driver => 'mysql',
	    -dbname => $self->o('ensembl_release'),
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -driver => 'mysql',
        },

        # By default, the pipeline will follow the "locator" of each
        # genome_db. You only have to set db_urls or reg_conf if the
        # locators are missing.

	#Location of core and, optionally, compara db
	#'db_urls' => [ $self->dbconn_2_url('staging_loc1'), $self->dbconn_2_url('staging_loc2') ],
	'db_urls' => [],

	#Alternative method of defining location of dbs
	'reg_conf' => '',

	#Compara reference to dump. Can be the "species" name (if loading via db_urls) or the url
        # Intentionally left empty
	#'compara_db' => 'Multi',

        'export_dir'    => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/dumps',

	'species'  => "human",
	'split_size' => 200,
	'masked_seq' => 1,
        'format' => 'emf',
        'dump_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/DumpMultiAlign.pl",
	'species_tree_file' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/species_tree.ensembl.topology.nw",

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

	#Store DumpMultiAlign other_gab genomic_align_block_ids
        $self->db_cmd('CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL)'),

	#Store DumpMultiAlign healthcheck results
        $self->db_cmd('CREATE TABLE healthcheck (filename VARCHAR(400) NOT NULL, expected INT NOT NULL, dumped INT NOT NULL)'),
    ];
}


# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack'  => 1,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'dump_program'  => $self->o('dump_program'),
        'format'        => $self->o('format'),
        'split_size'    => $self->o('split_size'),
        'export_dir'    => $self->o('export_dir'),
        'output_dir'    => '#export_dir#/#base_filename#',
    }
}

sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '2GbMem' => { 'LSF' => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
	 {  -logic_name => 'initJobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs',
            -input_ids => [
                {
                    'species'   => $self->o('species'),
                    'compara_db' => $self->o('compara_db'),
                    'mlss_id'    => $self->o('mlss_id'),
                }
            ],
            -flow_into => {
                '2->A' => [ 'createChrJobs' ],
                '3->A' => [ 'createSuperJobs' ],
                '1->A' => [ 'createOtherJobs' ],
		'A->1' => [ 'md5sum'],
            },
        },
	 {  -logic_name    => 'createChrJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs',
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ]
            }	    
        },
	{  -logic_name    => 'createSuperJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs',
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ]
            }
        },
	{  -logic_name    => 'createOtherJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateOtherJobs',
	   -rc_name => '2GbMem',
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ]
            }
        },
	{  -logic_name    => 'dumpMultiAlign',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign',

            -parameters    => {
                               'cmd' => [ 'perl', '#dump_program#', '--species', '#species#', '--mlss_id', '#mlss_id#', '--masked_seq', $self->o('masked_seq'), '--split_size', '#split_size#', '--output_format', '#format#', '--output_file', '#output_dir#/#base_filename#.#region_name#.#format#' ],
			       "reg_conf" => $self->o('reg_conf'),
			       "db_urls" => $self->o('db_urls'),
                               'output_file_pattern' => '#output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
			      },
	   -hive_capacity => 15,
	   -rc_name => '2GbMem',
           -flow_into => [ 'compress' ],
        },
        {   -logic_name     => 'compress',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'gzip -f -9 #output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
            },
            -hive_capacity => 200,
        },
	{   -logic_name     => 'md5sum',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'cd #output_dir#; md5sum *.#format#* > MD5SUM',
            },
            -flow_into      => [ 'readme' ],
        },
        {   -logic_name    => 'readme',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Readme',
            -parameters    => {
                'readme_file' => '#output_dir#/README.#base_filename#',
                'species_tree_file' => $self->o('species_tree_file'),
            },
        },    

    ];
}

1;
