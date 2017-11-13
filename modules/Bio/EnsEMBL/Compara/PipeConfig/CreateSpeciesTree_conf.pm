=pod

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CreateSpeciesTree_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'ensembl_release' => 90,
        'pipeline_name'   => 'species_tree_' . $self->o('ensembl_release'),
        'reg_conf'        => $self->o('ensembl_cvs_root_dir') . '/ensembl-compara/scripts/pipeline/production_reg_conf.pl',
        'collection'      => undef,
        'species_set_id'  => undef,
        'outgroup_gdbs'   => [134], # arrayref of genome_db_id for additional outgroup species
        
        'sketch_dir'       => '/nfs/nobackup/ensembl/carlac/species_tree/mash/ensembl_sketches',
        'mash_exe'         => '/nfs/gns/homes/carlac/bin/mash',
        'mash_kmer_size'   => 24, 
        'mash_sketch_size' => 1000000, 

        'master_db'          => "mysql://ensro\@mysql-ens-compara-prod-1:4485/ensembl_compara_master",
        'dump_genome_script' => $self->o('ensembl_cvs_root_dir') . '/ensembl-compara/scripts/dumps/dump_genome.pl',
        'rapidnj_exe'        => '/homes/carlac/software/rapidnj/bin-2.3.2/linux_64/rapidnj',

        'group_on_taxonomy' => 0,
        'representative_species' => undef,
        # 'representative_species' => ['homo_sapiens', 'mus_musculus'], # when group_on_taxonomy is set, define which species should act as the
                                                                      # representative for its taxonomic group - a default will be set if not defined
        # 'exclude_species'   => [ 'sorex_araneus', 'erinaceus_europaeus', 'oryctolagus_cuniculus', 'ochotona_princeps' ],
        'exclude_species' => undef,
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         'default'      => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '16Gb_job'     => {'LSF' => '-C0 -M16000  -R"select[mem>16000]  rusage[mem=16000]"' },
         '2Gb_8c_job'   => {'LSF' => '-n 8 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]  span[hosts=1]"' },
         '2Gb_reg_conf' => {'LSF' => ['-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', '--reg_conf '.$self->o('reg_conf')] },

    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'group_species',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GroupSpecies',
            -flow_into  => {
                1 => [ 'check_sketches' ],
            },
            -input_ids => [{
              'sketch_dir'        => $self->o('sketch_dir'),
              'collection'        => $self->o('collection'),
              'outgroup_gdbs'     => $self->o('outgroup_gdbs'),
              'species_set_id'    => $self->o('species_set_id'),
              'compara_db'        => $self->o('master_db'),
              'group_on_taxonomy' => $self->o('group_on_taxonomy'),
              'exclude_species'   => $self->o('exclude_species'),
            }],
        },

        {   -logic_name => 'check_sketches',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::CheckSketches',
            -flow_into  => {
                '2->A' => [ 'dump_genome' ],
                'A->1' => [ 'mash_paste' ],
            },
            -parameters => {
            	'sketch_dir'     => $self->o('sketch_dir'),
            	# 'collection'     => $self->o('collection'),
              # 'outgroup_gdbs'  => $self->o('outgroup_gdbs'),
            	# 'species_set_id' => $self->o('species_set_id'),
            	'compara_db'     => $self->o('master_db'),
            },
        },

        {   -logic_name => 'dump_genome',
            -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence',
        	  -flow_into  => {
                    1 => { 'mash_sketch' => { 'input_file' => '#genome_dump_file#', } },
        	},
        	# -parameters => {
        	# 	'dump_genome_script' => $self->o('dump_genome_script'),
        	# 	'compara_db'         => $self->o('master_db'),
        	# },
        	-rc_name => '2Gb_reg_conf',
          -analysis_capacity => 5,
        },

        {  -logic_name => 'mash_sketch',
        	-module    => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
        	-parameters => {
                'input_file'         => '#genome_dump_file#',
                'mode'               => 'sketch',
                'mash_exe'           => $self->o('mash_exe'),
                'out_dir'            => $self->o('sketch_dir'),
                'additional_options' => '-p 8', # use 8 processes & 10,000 sketch size
                'kmer_size'          => $self->o('mash_kmer_size'),
                'sketch_size'        => $self->o('mash_sketch_size'),
                'cleanup_input_file' => 0,
            },
            -rc_name => '2Gb_8c_job',
        },

        {  -logic_name => 'mash_paste',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
           -parameters => {
           		'mode'     => 'paste',
           		'mash_exe' => $self->o('mash_exe'),
           		'out_dir'  => $self->o('sketch_dir'),
           		'dataflow_branch' => 1,
           		'overwrite_paste_file' => 1,
           	},
           -flow_into  => {
           	   1  => ['mash_dist'],
               -1 => ['mash_paste_himem'],
            },
            -rc_name => '1Gb_job',
        },

        {  -logic_name => 'mash_paste_himem',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
           -parameters => {
              'mode'     => 'paste',
              'mash_exe' => $self->o('mash_exe'),
              'out_dir'  => $self->o('sketch_dir'),
              'dataflow_branch' => 1,
              'overwrite_paste_file' => 1,
            },
           -flow_into  => {
               1 => ['mash_dist'],
            },
            -rc_name => '16Gb_job',
        },

        {  -logic_name => 'mash_dist',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
           -parameters => {
                # 'input_file'      => '#mash_output_file#',
                'mode'            => 'dist',
                'mash_exe'        => $self->o('mash_exe'),
                'additional_options' => '-t', # tab delimited output
                'out_dir'         => $self->o('sketch_dir'),
                'dataflow_branch' => 1, # force runnable to flow mash output filename
                'output_as_input' => 1, # if multiple mash commands need to be run in succession,
                                        # allow param mash_output_file to be used in place of input_file
            },
           -flow_into => {
           	   1 => [ 'neighbour_joining_tree' ],
               -1 => [ 'mash_dist_himem' ],
           },
           -rc_name => '4Gb_job',
        },

        {  -logic_name => 'mash_dist_himem',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
           -parameters => {
                'mode'            => 'dist',
                'mash_exe'        => $self->o('mash_exe'),
                'additional_options' => '-t ', # tab delimited output
                'out_dir'         => $self->o('sketch_dir'),
                'dataflow_branch' => 1, # force runnable to flow mash output filename
                'output_as_input' => 1, # if multiple mash commands need to be run in succession,
                                        # allow param mash_output_file to be used in place of input_file
            },
           -flow_into => {
               1 => [ 'neighbour_joining_tree' ],
           },
           -rc_name => '16Gb_job',
        },

		# {  -logic_name => 'build_matrix',
  #          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::BuildMashDistanceMatrix',
  #          -parameters => {
  #          		'output_file' => $self->o('mega_file'),
  #          		'cleanup_distance_file' => 0,
  #          	},
  #          -flow_into  => {
  #          	   1 => [ 'neighbour_joining_tree' ],
  #          },
  #       },

        {  -logic_name => 'neighbour_joining_tree',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MashNJTree',
           -parameters => {
           		'rapidnj_exe'       => $self->o('rapidnj_exe'),
           		'output_file'       => $self->o('output_file'),
           		'compara_db'        => $self->o('master_db'),
              'group_on_taxonomy' => $self->o('group_on_taxonomy'),
           	},

        }       
    ];
}

1;