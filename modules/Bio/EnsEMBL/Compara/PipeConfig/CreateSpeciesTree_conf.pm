=pod

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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 DESCRIPTION

Pipeline to create species trees. If '--species_set_id' is provided, then '--collection' is ignored.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CreateSpeciesTree_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_pipeline_name {         # Instead of create_species_tree
    return 'species_tree';
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'collection'      => $self->o('division'), # build tree with everything by default
        'species_set_id'  => undef,

        # 'division'        => 'vertebrates',
        'outgroup'        => 'saccharomyces_cerevisiae',

        'output_dir'        => $self->o('pipeline_dir'),

        'mash_kmer_size'    => 24,
        'mash_sketch_size'  => 1000000,

        'master_db'          => 'compara_master',

        'representative_species' => undef,
        'taxonomic_ranks' => ['genus', 'family', 'order', 'class', 'phylum', 'kingdom'],
        'custom_groups'   => ['Vertebrata', 'Sauropsida', 'Amniota', 'Tetrapoda'],


        'unroot_script' => $self->check_exe_in_ensembl('ensembl-compara/scripts/species_tree/unroot_newick.py'),
        'reroot_script' => $self->check_exe_in_ensembl('ensembl-compara/scripts/species_tree/reroot_newick.py'),
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my $self = shift;

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir('output_dir'),
        # In case it doesn't exist yet
        'mkdir -p ' . $self->o('sketch_dir'),
    ];
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded
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
              'species_set_id'    => $self->o('species_set_id'),
              'compara_db'        => $self->o('master_db'),
              'outgroup'          => $self->o('outgroup'),
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
                'genome_dumps_dir' => $self->o('genome_dumps_dir'),
              'output_dir'     => $self->o('output_dir'),
            },
        },

        {   -logic_name => 'dump_genome',
            -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence',
        	  -flow_into  => {
                    1 => { 'mash_sketch' => { 'input_file' => '#genome_dump_file#', } },
        	},
                -rc_name => '2Gb_job',
          -analysis_capacity => 5,
        },

        {  -logic_name => 'mash_sketch',
        	-module    => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash',
        	-parameters => {
                'mode'               => 'sketch',
                'mash_exe'           => $self->o('mash_exe'),
                'output_dir'         => $self->o('output_dir'),
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
          -parameters => {
              'taxonomic_ranks' => $self->o('taxonomic_ranks'),
              'custom_groups'   => $self->o('custom_groups'  ),
              'genome_dumps_dir' => $self->o('genome_dumps_dir'),
          },
          -flow_into => {
              '2->A' => [ 'neighbour_joining_tree' ],
              'A->1' => [ 'graft_subtrees' ],
          },
          -rc_name => '1Gb_job',
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
              'output_file'   => $self->o('output_file'),
              'erable_exe'    => $self->o('erable_exe'),
              'unroot_script' => $self->o('unroot_script'),
              'reroot_script' => $self->o('reroot_script'),
              'genome_dumps_dir' => $self->o('genome_dumps_dir'),
          },
          -flow_into => {
              1 => ['copy_files_to_sketch_dir'],
          },
        },
        { -logic_name => 'copy_files_to_sketch_dir',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
          -parameters => {
              'destination_dir' => $self->o('sketch_dir'),
              'source_dir'      => $self->o('output_dir'),
              'cmd'             => 'cp #source_dir#/*.msh #destination_dir# && cp #source_dir#/#collection# #destination_dir#',
          },
        },
    ];
}

1;
