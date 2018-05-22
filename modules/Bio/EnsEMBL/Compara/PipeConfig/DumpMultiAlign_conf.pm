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

Initialise the pipeline on comparaY and dump the alignments found in the database msa_db_to_dump at comparaX:

  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db mysql://ensro@comparaX/msa_db_to_dump --export_dir where/the/dumps/will/be/

Dumps are created in a sub-directory of --export_dir, which defaults to scratch109

The pipeline can dump all the alignments it finds on a server, so you can do something like:

  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db mysql://ensro@ens-staging1/ensembl_compara_80 --registry path/to/production_reg_conf.pl
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db compara_prev --registry path/to/production_reg_conf.pl --format maf --method_link_types EPO

Note that in this case, because the locator field is not set, you need to provide a registry file

Format can be "emf", "maf", or anything BioPerl can provide (the pipeline will fail in the latter case, so
come and talk to us). It also accepts "emf+maf" to generate both emf and maf files


Release 65

 epo 6 way: 3.4 hours
 epo 12 way: 2.7 hours
 mercator/pecan 19 way: 5.5 hours
 low coverage epo 35 way: 43 hours (1.8 days)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpMultiAlign;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # By default, the pipeline will follow the "locator" of each
        # genome_db. You only have to set reg_conf if the locators
        # are missing.
        # 'registry' => '',
        'reg_conf' => undef,
        'curr_release' => $ENV{CURR_ENSEMBL_RELEASE},

        # Compara reference to dump. Can be the "species" name (if loading the Registry via registry)
        # or the url of the database itself
        # Intentionally left empty
        #'compara_db' => 'Multi',

        'export_dir'    => '/hps/nobackup2/production/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix'),

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

        'dump_aln_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/DumpMultiAlign.pl",
        'emf2maf_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/emf2maf.pl",

        # Method link types of mlss_id to retrieve
        'method_link_types' => 'BLASTZ_NET:TRANSLATED_BLAT:TRANSLATED_BLAT_NET:LASTZ_NET:PECAN:EPO:EPO_LOW_COVERAGE',

        # Specific mlss_id to dump. Leave undef as the pipeline can detect
        # it automatically
        'mlss_id'   => undef,

        'dump_aln_capacity' => 100,
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

        'dump_aln_program'      => $self->o('dump_aln_program'),
        'emf2maf_program'   => $self->o('emf2maf_program'),

        'make_tar_archive'      => $self->o('make_tar_archive'),
        'split_by_chromosome'   => $self->o('split_by_chromosome'),
        'format'        => $self->o('format'),
        'split_size'    => $self->o('split_size'),
        'registry'      => $self->o('registry') || $self->o('reg_conf'),
        'compara_db'    => $self->o('compara_db'),
        'export_dir'    => $self->o('export_dir'),
        'masked_seq'    => $self->o('masked_seq'),

        output_dir      => '#export_dir#/#format#/ensembl-compara/#aln_type#/#base_filename#',
        output_file_gen => '#output_dir#/#base_filename#.#region_name#.#format#',
        output_file     => '#output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
    };
}

sub resource_classes {
    my ($self) = @_;

    my $reg_options = $self->o('registry') ? '--reg_conf '.$self->o('registry') : '';
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        # 'crowd' => { 'LSF' => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
        'default_with_registry' => { 'LSF' => ['', $reg_options], 'LOCAL' => ['', $reg_options] },
        '2Gb_job' => { 'LSF' => ['-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"', $reg_options], 'LOCAL' => ['', $reg_options] },
        '2Gb_job_long' => { 'LSF' => ['-q long -C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"', $reg_options] },
    };
}

sub pipeline_create_commands {
    my $self = shift;

    return [
        @{ $self->SUPER::pipeline_create_commands },
        $self->db_cmd( 'CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL)' ),
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
