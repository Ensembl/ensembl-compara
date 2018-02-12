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

package Bio::EnsEMBL::Compara::PipeConfig::DumpConservationScores_conf;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Paths to compara files
        'dump_features_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'cs_readme'             => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/docs/ftp/conservation_scores.txt",
    };
}


sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'dump_features_program' => $self->o('dump_features_program'),
        'cs_readme'             => $self->o('cs_readme'),

        'registry'      => $self->o('registry'),
        'compara_url'   => $self->o('compara_url'),

        'export_dir'    => $self->o('export_dir'),
        'output_dir'    => '#export_dir#/#dirname#',
        'bedgraph_file' => '#output_dir#/gerp_conservation_scores.#name#.bedgraph',
        'bigwig_file'   => '#output_dir#/gerp_conservation_scores.#name#.bw',
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name     => 'mkdir',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConservationScores',
            -parameters     => {
                'compara_db'    => '#compara_url#',
            },
            -input_ids      => [
                {
                    'mlss_id'   => $self->o('mlss_id'),
                },
            ],
            -flow_into      => [ 'genomedb_factory' ],
        },

        {   -logic_name     => 'genomedb_factory',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters     => {
                'compara_db'            => '#compara_url#',
                'extra_parameters'      => [ 'name' ],
            },
            -flow_into      => {
                '2->A' => { 'dump_conservation_scores' => INPUT_PLUS() },
                'A->1' => [ 'md5sum' ],
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
            -flow_into      => [ 'compress' ],
        },

        {   -logic_name     => 'compress',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(gzip -f -9 #bedgraph_file#)],
            },
        },

        {   -logic_name     => 'md5sum',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => 'cd #output_dir#; md5sum *.bedgraph.gz *.bw > MD5SUM',
            },
            -flow_into      =>  [ 'readme' ],
        },

        {   -logic_name     => 'readme',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(cp -af #cs_readme# #output_dir#/README)],
            },
        },
    ];
}

1;
