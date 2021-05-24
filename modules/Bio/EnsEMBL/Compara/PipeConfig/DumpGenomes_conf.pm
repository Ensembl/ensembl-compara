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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf

=head1 SYNOPSIS

    # Typical invocation
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

    # Different species-set
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -collection_name '' -mlss_id 1234

=head1 DESCRIPTION

Pipeline to dump the genomic sequences of a given species-set. All masking
flavours are generated (unmasked, soft-masked and hard-masked), and all the
files are indexed (faidx) to allow fast access with Bio::DB::HTS.

Furthermore, the genomes that are included in an EPO pipeline will also be
indexed for exonerate.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf;

use strict;
use warnings;

# We need WHEN and INPUT_PLUS
use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        # Which species-set to dump
        'species_set_id'    => undef,
        'species_set_name'  => undef,
        'collection_name'   => $self->o('division'),
        'mlss_id'           => undef,
        'all_current'       => undef,

        # the master database to get the genome_dbs
        'master_db'         => 'compara_master',
        # the pipeline won't redump genomes unless their size is different, or listed here
        'force_redump'      => [],

        # Capacities
        'dump_capacity'     => 10,
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

        'reg_conf'          => $self->o('reg_conf'),
        'compara_db'        => $self->o('master_db'),
        'genome_dumps_dir'  => $self->o('genome_dumps_dir'),
    };
}


sub pipeline_analyses {
    my $self = shift;

    return [
        {   -logic_name => 'genome_dump_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'extra_parameters'  => [ 'locator', 'methods' ],
                'fetch_methods'     => 1,
            },
            -input_ids  => [{
                    # Definition of the species-set
                    'species_set_id'    => $self->o('species_set_id'),
                    'species_set_name'  => $self->o('species_set_name'),
                    'collection_name'   => $self->o('collection_name'),
                    'mlss_id'           => $self->o('mlss_id'),
                    'all_current'       => $self->o('all_current'),
                }],
            -flow_into  => {
                2 => [
                    'genome_dump_unmasked', 'genome_dump_masked',
                    'genome_dump_unmasked_non_ref', 'genome_dump_masked_non_ref',
                ],
            },
        },

        # NOTE: DumpMaskedGenomeSequence creates two files (soft- and hard-masked),
        # so dataflows on branch #2, whereas DumpUnmaskedGenomeSequence creates a single
        # file and is allowed to amend the dataflow on branch #1

        # NOTE: The unmasked genome is dumped separately in order to get it
        # done quicker (and start the exonerate indexing quicker). This is
        # because fetching the masked DNA sequences is significantly slower
        # than the unmasked DNA sequences.
        # Otherwise, just like the hard-masked file is made from the
        # soft-masked file by replacing a-z with N, the unmasked file could
        # have been made by replacing a-z with A-Z.

        {   -logic_name => 'genome_dump_unmasked',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpUnmaskedGenomeSequence',
            -parameters => {
                'force_redump'  => $self->o('force_redump'),
            },
            -flow_into  => [ 'build_faidx_index', WHEN('#methods#->{"EPO"}' => [ 'build_exonerate_esd_index' ]), ],
            -rc_name    => '4Gb_job',
            -priority   => 10,
            -hive_capacity  => $self->o('dump_capacity'),
        },

        {   -logic_name => 'genome_dump_masked',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpMaskedGenomeSequence',
            -parameters => {
                'force_redump'  => $self->o('force_redump'),
            },
            -flow_into  => {
                2 => [ 'build_faidx_index' ],
            },
            -rc_name    => '4Gb_job',
            -hive_capacity  => $self->o('dump_capacity'),
        },

        {   -logic_name => 'genome_dump_unmasked_non_ref',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpUnmaskedGenomeSequence',
            -parameters => {
                'is_reference'  => 0,
                'force_redump'  => $self->o('force_redump'),
            },
            -flow_into  => [ 'build_faidx_index' ],
            -rc_name    => '4Gb_job',
            -hive_capacity  => $self->o('dump_capacity'),
        },

        {   -logic_name => 'genome_dump_masked_non_ref',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpMaskedGenomeSequence',
            -parameters => {
                'is_reference'  => 0,
                'force_redump'  => $self->o('force_redump'),
            },
            -flow_into  => {
                2 => [ 'build_faidx_index' ],
            },
            -rc_name    => '4Gb_job',
            -hive_capacity  => $self->o('dump_capacity'),
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

        {   -logic_name => 'build_exonerate_esd_index',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'fasta2esd_exe' => $self->o('fasta2esd_exe'),
                'input_file'    => '#genome_dump_file#',
                'output_file'   => '#genome_dump_file#.esd',
                'tmp_file'      => '#output_file#.tmp',
                'command'       => '#fasta2esd_exe# #input_file# #tmp_file#',
                # 1. Rerun the command if the output file is missing or if the input file has been recently modified
                # 2. Run the command in a pseudo-transaction manner, i.e.  the output file is only modified if the command succeeds
                'cmd'           => '(test -e #output_file# && test #input_file# -ot #output_file#) || (rm --force #tmp_file# && #command# && mv --force #tmp_file# #output_file#)',
            },
            -flow_into  => [ 'build_exonerate_esi_index' ],
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'build_exonerate_esi_index',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'esd2esi_exe'   => $self->o('esd2esi_exe'),
                'input_file'    => '#genome_dump_file#.esd',
                'output_file'   => '#genome_dump_file#.esi',
                'tmp_file'      => '#output_file#.tmp',
                'command'       => '#esd2esi_exe# #input_file# #tmp_file#',
                # 1. Rerun the command if the output file is missing or if the input file has been recently modified
                # 2. Run the command in a pseudo-transaction manner, i.e.  the output file is only modified if the command succeeds
                'cmd'           => '(test -e #output_file# && test #input_file# -ot #output_file#) || (rm --force #tmp_file# && #command# && mv --force #tmp_file# #output_file#)',
            },
            -rc_name    => '2Gb_job',
        },
    ];
}


1;
