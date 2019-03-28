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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf

=head1 DESCRIPTION

Pipeline to dump the genomic sequences of a given species-set. All masking
flavours are generated (unmasked, soft-masked and hard-masked), and all the
files are indexed (faidx) to allow fast access with Bio::DB::HTS.

Furthermore, the genomes that are included in an EPO pipeline will also be
indexed for exonerate.

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpGenomes_conf -division vertebrates

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpGenomes_conf -division plants

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf;

use strict;
use warnings;

# We need WHEN and INPUT_PLUS
use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        # In case it doesn't exist yet
        'become ' . $self->o('shared_user') . ' mkdir -p '.$self->o('genome_dumps_dir'),
        # The files are going to be accessed by many processes in parallel
        $self->pipeline_create_commands_lfs_setstripe('genome_dumps_dir', $self->o('shared_user')),
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'reg_conf'          => $self->o('reg_conf'),
        'shared_user'       => $self->o('shared_user'),
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
                2 => { 'genome_dump_unmasked' => INPUT_PLUS(), 'genome_dump_masked' => INPUT_PLUS(), }, # To allow propagating "reg_conf" if the latter is defined at the job level
            },
        },

        {   -logic_name => 'genome_dump_unmasked',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpUnmaskedGenomeSequence',
            -parameters => {
                'force_redump'  => $self->o('force_redump'),
            },
            -flow_into  => [ 'build_faidx_index', WHEN('#methods#->{"EPO"}' => [ 'build_exonerate_esd_index' ]), ],
            -rc_name    => '4Gb_job',
            -priority   => 10,
            -hive_capacity  => $self->o('dump_capacity'),
        },

        {   -logic_name => 'genome_dump_masked',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMaskedGenomeSequence',
            -parameters => {
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
                'cmd'           => '(test -e #output_file# && test #input_file# -ot #output_file#) || become #shared_user# #command#',
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
                'cmd'           => '(test -e #output_file# && test #input_file# -ot #output_file#) || (become #shared_user# rm --force #tmp_file# && become #shared_user# #command# && become #shared_user# mv --force #tmp_file# #output_file#)',
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
                'cmd'           => '(test -e #output_file# && test #input_file# -ot #output_file#) || (become #shared_user# rm --force #tmp_file# && become #shared_user# #command# && become #shared_user# mv --force #tmp_file# #output_file#)',
            },
            -rc_name    => '2Gb_job',
        },
    ];
}


1;
