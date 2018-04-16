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

Pipeline to dump conservation scores as bedGraph and bigWig files

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
            -parameters     => {
                'compara_db'    => '#compara_url#',
            },
            # -input_ids      => [
            #     {
            #         'mlss_id'   => $self->o('mlss_id'),
            #     },
            # ],
            -flow_into      => [ 'genomedb_factory_cs' ],
        },

        {   -logic_name     => 'genomedb_factory_cs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters     => {
                'compara_db'            => '#compara_url#',
                'extra_parameters'      => [ 'name' ],
            },
            -flow_into      => {
                '2->A' => { 'dump_conservation_scores' => INPUT_PLUS() },
                'A->1' => [ 'md5sum_cs' ],
            },
        },

        {   -logic_name     => 'dump_conservation_scores',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => '#dump_features_program# --feature cs_#mlss_id# --compara_url #compara_url# --species #name# --lex_sort --reg_conf "#registry#" > #bedgraph_file#',
            },
            -analysis_capacity => $self->o('capacity'),
            -rc_name        => 'crowd',
            -flow_into      => [ 'convert_to_bigwig' ],
        },

        {   -logic_name     => 'convert_to_bigwig',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::ConvertToBigWig',
            -parameters     => {
                'compara_db'    => '#compara_url#',
                'big_wig_exe'   => $self->o('big_wig_exe'),
            },
            -rc_name        => 'crowd',
            -flow_into      => [ 'compress_cs' ],
        },

        {   -logic_name     => 'compress_cs',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(gzip -f -9 #bedgraph_file#)],
            },
        },

        {   -logic_name     => 'md5sum_cs',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => 'cd #output_dir#; md5sum *.bedgraph.gz *.bw > MD5SUM',
            },
            -flow_into      =>  [ 'readme_cs' ],
        },

        {   -logic_name     => 'readme_cs',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(cp -af #cs_readme# #output_dir#/README)],
            },
        },
    ];
}

1;
