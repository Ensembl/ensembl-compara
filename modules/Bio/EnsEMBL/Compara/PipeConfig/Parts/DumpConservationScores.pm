=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 DESCRIPTION

    This is a partial PipeConfig for most part of the pipeline that dumps the
    conservation scores as bedGraph and bigWig files.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConservationScores;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

sub pipeline_analyses_dump_conservation_scores {
    my ($self) = @_;
    return [

        {   -logic_name     => 'mkdir_conservation_scores',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConservationScores',
            -flow_into      => [ 'genomedb_factory_cs' ],
        },

        {   -logic_name     => 'genomedb_factory_cs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters     => {
                'extra_parameters'      => [ 'name', 'assembly' ],
            },
            -flow_into      => {
                '2->A' => { 'region_factory' => INPUT_PLUS() },
                'A->1' => [ 'md5sum_cs' ],
            },
        },

        {   -logic_name     => 'region_factory',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ChunkAndGroupDnaFrags',
            -parameters     => {
                'chunk_size'    => 10_000_000,
            },
            -flow_into      => {
                '2->A' => { 'dump_conservation_scores' => INPUT_PLUS() },
                'A->1' => [ 'concatenate_bedgraph_files' ],
            },
        },

        {   -logic_name        => 'dump_conservation_scores',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpConservationScores',
            -hive_capacity     => $self->o('dump_cs_capacity'),
            -rc_name           => '2Gb_job',
            -flow_into         => {
                1 => '?accu_name=all_bedgraph_files&accu_address=[chunkset_id]&accu_input_variable=this_bedgraph',
            },
        },

        {   -logic_name     => 'concatenate_bedgraph_files',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateBedGraphFiles',
            -flow_into      => 'convert_to_bigwig',
        },

        {   -logic_name     => 'convert_to_bigwig',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [ $self->o('big_wig_exe'), '#bedgraph_file#', '#chromsize_file#', '#bigwig_file#' ],
            },
            -rc_name        => '16Gb_job',
        },

        {   -logic_name     => 'md5sum_cs',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => 'cd #cs_output_dir#; md5sum *.bw > MD5SUM',
            },
            -flow_into      =>  [ 'readme_cs' ],
        },

        {   -logic_name     => 'readme_cs',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(cp -af #cs_readme# #cs_output_dir#/README)],
            },
        },
    ];
}

1;
