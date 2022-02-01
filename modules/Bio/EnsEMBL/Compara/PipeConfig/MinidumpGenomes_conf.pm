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

Bio::EnsEMBL::Compara::PipeConfig::MinidumpGenomes_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MinidumpGenomes_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Minipipeline to dump the genomic sequences of a given species-set (unmasked only).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MinidumpGenomes_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'division'         => 'vertebrates',
        'master_db'        => 'compara_master',
        'master_url'       => 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master',
        'work_dir'         => '/hps/nobackup/flicek/ensembl/compara/jalvarez/pluggable_test_files/',
        'genome_dumps_dir' => $self->o('work_dir') . '/dumps_hive',
        'species_file'     => $self->o('work_dir') . '/species.json',
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        # In case it doesn't exist yet
        'mkdir -p ' . $self->o('genome_dumps_dir'),
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'reg_conf'         => $self->o('reg_conf'),
        'compara_db'       => $self->o('master_db'),
        'master_url'       => $self->o('master_url'),
        'genome_dumps_dir' => $self->o('genome_dumps_dir'),
    };
}


sub pipeline_analyses {
    my $self = shift;

    return [
        {   -logic_name => 'genome_dump_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -input_ids  => [{
                'species_json'  => $self->o('species_file'),
                'bin'           => $ENV{'ENSEMBL_ROOT_DIR'} . '/ensembl-compara/scripts/pipeline/get_gdb_id.py',
                'dataflow_file' => $self->o('work_dir') . '/dataflow.json',
                'cmd'           => '#bin# --url #master_url# --species #species_json# > #dataflow_file#',
            }],
            -flow_into  => [ 'genome_dump_unmasked' ],
        },

        {   -logic_name => 'genome_dump_unmasked',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpUnmaskedGenomeSequence',
            -parameters => {
                'force_redump' => [],
            },
            -rc_name    => '1Gb_job',
            -flow_into  => [ 'build_faidx_index' ],
        },

        {   -logic_name => 'build_faidx_index',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'samtools_exe'  => $self->o('samtools_exe'),
                'input_file'    => '#genome_dump_file#',
                'output_file'   => '#genome_dump_file#.fai',
                'command'       => '#samtools_exe# faidx #input_file#',
                # Rerun the command if the output file is missing or if the input file has been recently modified
                'cmd'           => '(test -e #output_file# && test #input_file# -ot #output_file#) || #command#',
            },
        },
    ];
}


1;
