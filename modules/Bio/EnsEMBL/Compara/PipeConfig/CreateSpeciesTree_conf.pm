=pod

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'ensembl_release' => 92,
        'pipeline_name'   => 'species_tree_' . $self->o('ensembl_release'),
        'reg_conf'        => $self->o('ensembl_cvs_root_dir') . '/ensembl-compara/scripts/pipeline/production_reg_conf.pl',
        'collection'      => 'ensembl', # build tree with everything by default
        'species_set_id'  => undef,
        'outgroup'        => 'saccharomyces_cerevisiae',
        
        'output_dir'        => "/gpfs/nobackup/ensembl/". $self->o('ENV', 'USER'). "/species_tree_" . $self->o('ensembl_release'),
        'sketch_dir'        => '/hps/nobackup/production/ensembl/compara_ensembl/species_tree/ensembl_sketches',
        'write_access_user' => 'compara_ensembl', # if the current user does not have write access to
                                                  # sketch_dir, 'become' this user to place files there
        
        'mash_exe'          => $self->check_exe_in_cellar('mash/2.0/bin/mash'),
        'mash_kmer_size'    => 24, 
        'mash_sketch_size'  => 1000000, 

        'master_db'          => "mysql://ensro\@mysql-ens-compara-prod-1:4485/ensembl_compara_master",
        'dump_genome_script' => $self->o('ensembl_cvs_root_dir') . '/ensembl-compara/scripts/dumps/dump_genome.pl',
        'rapidnj_exe'        => $self->o('linuxbrew_bin').'/rapidnj',
        'erable_exe'         => $self->o('linuxbrew_bin').'/erable',
        'multifasta_dir'     => undef, # define if species multifastas have been pre-dumped

        'group_on_taxonomy' => 0,
        'representative_species' => undef,
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

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my $self = shift;

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        'mkdir -p '.$self->o('output_dir'),
    ];
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        # 'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
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
              'species_set_id'    => $self->o('species_set_id'),
              'compara_db'        => $self->o('master_db'),
            }],
        },

        {   -logic_name => 'check_sketches',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::CheckSketches',
            -flow_into  => {
                '2->A' => [ 'dump_genome' ],
                '3->A' => [ 'mash_sketch' ],
                'A->1' => [ 'mash_paste' ],
                '4'    => [ 'permute_matrix' ],
            },
            -parameters => {
            	'sketch_dir'     => $self->o('sketch_dir'),
            	'compara_db'     => $self->o('master_db'),
            	'multifasta_dir' => $self->o('multifasta_dir'),
              'output_dir'     => $self->o('output_dir'),
            },
        },

        {   -logic_name => 'dump_genome',
            -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence',
        	  -flow_into  => {
                    1 => { 'mash_sketch' => { 'input_file' => '#genome_dump_file#', } },
        	},
        	-rc_name => '2Gb_reg_conf',
          -analysis_capacity => 5,
        },

        {  -logic_name => 'mash_sketch',
        	-module    => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
        	-parameters => {
                'mode'               => 'sketch',
                'mash_exe'           => $self->o('mash_exe'),
                'output_dir'            => $self->o('output_dir'),
                'additional_options' => '-p 8', # use 8 processes
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
           		'output_dir'  => $self->o('output_dir'),
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
              'output_dir' => $self->o('output_dir'),
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
                'mode'            => 'dist',
                'mash_exe'        => $self->o('mash_exe'),
                'additional_options' => '-t', # tab delimited output
                'output_dir'         => $self->o('output_dir'),
                'dataflow_branch' => 1, # force runnable to flow mash output filename
                'output_as_input' => 1, # if multiple mash commands need to be run in succession,
                                        # allow param mash_output_file to be used in place of input_file
            },
           -flow_into => {
           	   1 => { 'permute_matrix' => { 'mash_dist_file' => "#mash_output_file#" } },
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
                'output_dir'         => $self->o('output_dir'),
                'dataflow_branch' => 1, # force runnable to flow mash output filename
                'output_as_input' => 1, # if multiple mash commands need to be run in succession,
                                        # allow param mash_output_file to be used in place of input_file
            },
           -flow_into => {
               1 => { 'permute_matrix' => { 'mash_dist_file' => "#mash_output_file#" } },
           },
           -rc_name => '16Gb_job',
        },

        { -logic_name => 'permute_matrix',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::PermuteMatrix',
          -flow_into => {
              '2->A' => [ 'neighbour_joining_tree' ],
              'A->1' => [ 'graft_subtrees' ],
          }
        },

        {  -logic_name => 'neighbour_joining_tree',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MashNJTree',
           -parameters => {
           		'rapidnj_exe'       => $self->o('rapidnj_exe'),
           		'compara_db'        => $self->o('master_db'),
           	},
            -flow_into => {
                1 => [ '?accu_name=trees&accu_address={group_key}&accu_input_variable=group_info' ],
            },
        },

        { -logic_name => 'graft_subtrees',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GraftSubtrees',
          -parameters => {
              'outgroup'    => $self->o('outgroup'),
          },
          -flow_into => {
                1 => ['adjust_branch_lengths'],
          },
        },

        { -logic_name => 'adjust_branch_lengths',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::AdjustBranchLengths',
          -parameters => {
              'output_file' => $self->o('output_file'),
              'erable_exe'  => $self->o('erable_exe'),
          },
          -flow_into => {
              1 => ['copy_files_to_sketch_dir'],
          },
        },

        { -logic_name => 'copy_files_to_sketch_dir',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::CopyFilesAsUser',
          -parameters => {
              'destination_dir' => $self->o('sketch_dir'),
              'become_user'     => $self->o('write_access_user'),
              'source_dir'      => $self->o('output_dir'),
              'file_list' => [
                '#source_dir#/*.msh',
                '#source_dir#/*.dists',
              ],
          },
        },    
    ];
}

1;
