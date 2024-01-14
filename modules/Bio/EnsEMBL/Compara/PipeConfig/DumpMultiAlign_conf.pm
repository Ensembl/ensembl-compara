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

Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

Pipeline to dump all the multiple sequence alignments from the given
compara database. To dump only certain method link (ml) types, set them
in --method_link_types with the following regex: ml(:ml)*.
E.g.: --method_link_types EPO:PECAN

The dumps are located in the pipeline's directory. This can be changed by
setting --export_dir.

The pipeline generates both EMF and MAF files ("emf+maf"). This can be
changed by setting --format to "emf", "maf", or anything BioPerl can
provide.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpMultiAlign;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Compara reference to dump. Can be the "species" name (if loading the Registry via registry)
        # or the url of the database itself
        'compara_db' => 'compara_curr',

        'export_dir'    => $self->o('pipeline_dir'),

        # List of species used to split EPO alignments. Required if split_by_chromosome is set
        'epo_reference_species' => [],

        # Maximum number of blocks per file
        'split_size' => 200,

        # See DumpMultiAlign.pl
        #  0 for unmasked sequence (default)
        #  1 for soft-masked sequence
        #  2 for hard-masked sequence
        'masked_seq' => 1,

        # Usually "maf", "emf", or "emf+maf". BioPerl alignment formats are
        # accepted in principle, but a healthcheck would have to be implemented
        'format' => 'emf+maf',

        # If set to 1, will make a compressed tar archive of a directory of
        # uncompressed files. Otherwise, there will be a directory of
        # compressed files
        'make_tar_archive'  => 0,

        # If set to 1, the files are split by chromosome name and
        # coordinate system. Otherwise, createOtherJobs randomly bins the
        # alignment blocks into chunks
        'split_by_chromosome'   => 1,

        # Method link types of mlss_id to retrieve
        'method_link_types' => 'BLASTZ_NET:TRANSLATED_BLAT:TRANSLATED_BLAT_NET:LASTZ_NET:PECAN:EPO:EPO_EXTENDED',

        # Specific mlss_id to dump. Leave undef as the pipeline can detect
        # it automatically
        'mlss_id'   => undef,

        'dump_aln_capacity' => 100,
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

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

        'dump_aln_program'      => $self->o('dump_aln_program'),
        'emf2maf_program'   => $self->o('emf2maf_program'),

        'make_tar_archive'      => $self->o('make_tar_archive'),
        'split_by_chromosome'   => $self->o('split_by_chromosome'),
        'format'        => $self->o('format'),
        'split_size'    => $self->o('split_size'),
        'compara_db'    => $self->o('compara_db'),
        'export_dir'    => $self->o('export_dir'),
        'masked_seq'    => $self->o('masked_seq'),
        'genome_dumps_dir' => $self->o('genome_dumps_dir'),

        output_dir      => '#export_dir#/#format#/ensembl-compara/#aln_type#/#base_filename#',
        output_file_gen => '#output_dir#/#base_filename#.#region_name#.#format#',
        output_file     => '#output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
    };
}

sub pipeline_create_commands {
    my $self = shift;

    return [
        @{ $self->SUPER::pipeline_create_commands },
        $self->db_cmd( 'CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL, PRIMARY KEY (genomic_align_block_id) )' ),
        $self->db_cmd( 'CREATE TABLE healthcheck (filename VARCHAR(400) NOT NULL, expected INT NOT NULL, dumped INT NOT NULL)' ),
    ];
}

sub pipeline_analyses {
    my ($self) = @_;
    
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpMultiAlign::pipeline_analyses_dump_multi_align($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [
        {
            'compara_db'        => $self->o('compara_db'),
            'mlss_id'           => $self->o('mlss_id'),
        },
    ];

    return $pipeline_analyses;
}

1;
