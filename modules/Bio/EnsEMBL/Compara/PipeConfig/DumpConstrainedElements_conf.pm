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

Initialise the pipeline on compara1 and dump the constrained elements of mlss_id 836
found at cc21_ensembl_compara_86 on compara5

  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf -compara_url mysql://ensro@compara5/cc21_ensembl_compara_86 -mlss_id 836 -host compara1 -registry $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl

Dumps are created in a sub-directory of --export_dir, which defaults to scratch109

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'host' => 'mysql-ens-compara-prod-1',
        'port' => 4485,

        # Where dumps are created
        'export_dir'    => '/hps/nobackup/production/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix'),

        # Paths to compara files
        'dump_features_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'ce_readme'             => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/docs/ftp/constrained_elements.txt",

        # How many species can be dumped in parallel
        'capacity'    => 50,
    };
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

        'dump_features_program' => $self->o('dump_features_program'),
        'ce_readme'             => $self->o('ce_readme'),

        'registry'      => $self->o('registry'),
        'compara_url'   => $self->o('compara_url'),

        'export_dir'    => $self->o('export_dir'),
        'output_dir'    => '#export_dir#/bed/ensembl-compara/#dirname#',
        'output_file'   => '#output_dir#/gerp_constrained_elements.#name#.bed',
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name     => 'mkdir',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConstrainedElements',
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
                '2->A' => [ 'dump_constrained_elements' ],
                'A->1' => [ 'md5sum' ],
            },
        },

        {   -logic_name     => 'dump_constrained_elements',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => '#dump_features_program# --feature ce_#mlss_id# --compara_url #compara_url# --species #name# --reg_conf "#registry#" > #output_file#',
            },
            -analysis_capacity => $self->o('capacity'),
            -flow_into      => [ 'check_not_empty' ],
        },

        {   -logic_name     => 'check_not_empty',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CheckNotEmpty',
            -parameters     => {
                'min_number_of_lines'   => 1,   # The header is always present
                'filename'              => '#output_file#',
            },
            -flow_into      => [ 'compress' ],
        },

        {   -logic_name     => 'compress',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(gzip -f -9 #output_file#)],
            },
        },

        {   -logic_name     => 'md5sum',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => 'cd #output_dir#; md5sum *.bed.gz > MD5SUM',
            },
            -flow_into      =>  [ 'readme' ],
        },

        {   -logic_name     => 'readme',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(cp -af #ce_readme# #output_dir#/README)],
            },
        },
    ];
}

1;
