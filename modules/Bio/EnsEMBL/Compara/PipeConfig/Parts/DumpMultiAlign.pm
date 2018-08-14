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

=head1 SYNOPSIS


=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpMultiAlign;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

sub pipeline_analyses_dump_multi_align {
    my ($self) = @_;
    return [
        {   -logic_name    => 'DumpMultiAlign_MLSSJobFactory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory',
            -parameters    => {
                'method_link_types' => $self->o('method_link_types'),
                'from_first_release' => $self->o('ensembl_release'),
            },
            # -input_ids     => [
            #     {
            #         'mlss_id'           => $self->o('mlss_id'),
            #     },
            # ],
            -flow_into      => {
                '2->A' => [ 'count_blocks' ],
                'A->2' => [ 'md5sum_aln_factory' ],
            },
            -rc_name => 'default_with_registry',
        },

        {  -logic_name  => 'count_blocks',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'       => '#compara_db#',
                'inputquery'    => 'SELECT COUNT(*) AS num_blocks FROM genomic_align_block WHERE method_link_species_set_id = #mlss_id#',
            },
            -flow_into  => {
                2 => WHEN(
                    '#split_by_chromosome#' => [ 'initJobs' ],
                    '!#split_by_chromosome# && #split_size#>0' => { 'createOtherJobs' => {'do_all_blocks' => 1} },
                    '!#split_by_chromosome# && #split_size#==0' => { 'dumpMultiAlign' => {'region_name' => 'all', 'filename_suffix' => '*', 'num_blocks' => '#num_blocks#'} },    # a job to dump all the blocks in 1 file
                ),
            },
            -rc_name    => 'default_with_registry',
        },

        {  -logic_name  => 'initJobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs',
            -hive_capacity => $self->o('dump_aln_capacity'),
            -flow_into => {
                2 => [ 'createChrJobs' ],
                3 => [ 'createSuperJobs' ],
                4 => [ 'createOtherJobs' ],
            },
            -rc_name => 'default_with_registry',
        },
        # Generates DumpMultiAlign jobs from genomic_align_blocks on chromosomes (1 job per chromosome)
        {  -logic_name    => 'createChrJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs',
            -hive_capacity => $self->o('dump_aln_capacity'),
            -flow_into => {
                2 => [ 'dumpMultiAlign' ]
            },
            -rc_name => 'default_with_registry',
        },
        # Generates DumpMultiAlign jobs from genomic_align_blocks on supercontigs (1 job per coordinate-system)
        {  -logic_name    => 'createSuperJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs',
            -hive_capacity => $self->o('dump_aln_capacity'),
            -flow_into => {
                2 => [ 'dumpMultiAlign' ]
            },
            -rc_name => 'default_with_registry',
        },
        # Generates DumpMultiAlign jobs from genomic_align_blocks that do not contain $species
        {  -logic_name    => 'createOtherJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateOtherJobs',
            -hive_capacity => $self->o('dump_aln_capacity'),
            -flow_into => {
                2 => [ 'dumpMultiAlign' ]
            },
            -rc_name => '2Gb_job',
        },
        {  -logic_name    => 'dumpMultiAlign',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign',
            -hive_capacity => $self->o('dump_aln_capacity'),
            -rc_name => '2Gb_job',
            -max_retry_count    => 0,
            -flow_into => [ WHEN(
                '#run_emf2maf#' => [ 'emf2maf' ],
                '!#run_emf2maf# && !#make_tar_archive#' => [ 'compress_aln' ],
                # '!#make_tar_archive#' => [ 'compress_aln' ],
            ) ],
        },
        {   -logic_name     => 'emf2maf',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf',
            -rc_name        => '2Gb_job',
            -flow_into => [
                WHEN( '!#make_tar_archive#' => { 'compress_aln' => [ undef, { 'format' => 'maf'} ] } ),
            ],
        },
        {   -logic_name     => 'compress_aln',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'gzip -f -9 #output_file#',
            },
        },

        {   -logic_name     => 'md5sum_aln_factory',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MD5SUMFactory',
            -flow_into     => {
                '2->A' => [ 'md5sum_aln' ],
                'A->1' => [ 'pipeline_end' ],
            },
        },
        {   -logic_name     => 'md5sum_aln',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'cd #output_dir#; md5sum *.#format#* > MD5SUM',
            },
            -flow_into      =>  [ 'readme' ],
        },
        {   -logic_name    => 'readme',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Readme',
            -parameters    => {
                'readme_file' => '#output_dir#/README.#base_filename#',
            },
            -flow_into     => WHEN( '#make_tar_archive#' => [ 'targz' ] ),
            -rc_name => 'default_with_registry',
        },
        {   -logic_name     => 'targz',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'cd #export_dir#; tar czf #base_filename#.tar.gz #base_filename#; rm -r #base_filename#',
            },
        },

        {   -logic_name     => 'pipeline_end',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },
    ];
}

1;
