=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db mysql://ensro@ens-staging1/ensembl_compara_80 --reg_conf path/to/production_reg_conf.pl
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db compara_prev --reg_conf path/to/production_reg_conf.pl --format maf --method_link_types EPO

Note that in this case, because the locator field is not set, you need to provide a registry file

Format can be "emf", "maf", or anything BioPerl can provide (the pipeline will fail in the latter case, so
come and talk to us). To mimic the old "emf+maf" output, you now have to run the pipeline twice: the first
time with "emf", and the second with "emf2maf". it will then read the EMF files created by the first instance.


Release 65

 epo 6 way: 3.4 hours
 epo 12 way: 2.7 hours
 mercator/pecan 19 way: 5.5 hours
 low coverage epo 35 way: 43 hours (1.8 days)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # By default, the pipeline will follow the "locator" of each
        # genome_db. You only have to set reg_conf if the locators
        # are missing.
        'reg_conf' => '',

        # Compara reference to dump. Can be the "species" name (if loading the Registry via reg_conf)
        # or the url of the database itself
        # Intentionally left empty
        #'compara_db' => 'Multi',

        'export_dir'    => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix'),

        # Maximum number of blocks per file
        'split_size' => 200,

        # See DumpMultiAlign.pl
        #  0 for unmasked sequence (default)
        #  1 for soft-masked sequence
        #  2 for hard-masked sequence
        'masked_seq' => 1,

        # Usually "maf", "emf", or "emf2maf". BioPerl alignment formats are
        # accepted in principle, but a healthcheck would have to be implemented
        'format' => 'emf',

        # one of 'dir' (directory of compressed files), 'tar' (compressed tar archive of a directory of uncompressed files), or 'file' (single compressed file)
        'mode' => 'dir',
        # how the files will be split: either 'chromosome' or 'random'
        'split_mode' => 'chromosome',

        'dump_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/DumpMultiAlign.pl",
        'emf2maf_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/emf2maf.pl",

        # Method link types of mlss_id to retrieve
        'method_link_types' => 'BLASTZ_NET:TRANSLATED_BLAT:TRANSLATED_BLAT_NET:LASTZ_NET:PECAN:EPO:EPO_LOW_COVERAGE',

        # Specific mlss_id to dump. Leave undef as the pipeline can detect
        # it automatically
        'mlss_id'   => undef,
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

        'dump_program'      => $self->o('dump_program'),
        'emf2maf_program'   => $self->o('emf2maf_program'),

        'format'        => $self->o('format'),
        'split_size'    => $self->o('split_size'),
	'reg_conf' => $self->o('reg_conf'),
        'export_dir'    => $self->o('export_dir'),
    };
}

sub resource_classes {
    my ($self) = @_;

    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'crowd' => { 'LSF' => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
        'default_with_reg_conf' => { 'LSF' => ['', '--reg_conf '.$self->o('reg_conf')], 'LOCAL' => ['', '--reg_conf '.$self->o('reg_conf')] },
        'crowd_with_reg_conf' => { 'LSF' => ['-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"', '--reg_conf '.$self->o('reg_conf')], 'LOCAL' => ['', '--reg_conf '.$self->o('reg_conf')] },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name     => 'create_tracking_tables',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'    => [
                    #Store DumpMultiAlign other_gab genomic_align_block_ids
                    'CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL)',
                    #Store DumpMultiAlign healthcheck results
                    'CREATE TABLE healthcheck (filename VARCHAR(400) NOT NULL, expected INT NOT NULL, dumped INT NOT NULL)',
                ],
            },
            -input_ids     => [ {} ],
        },

        {   -logic_name    => 'MLSSJobFactory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory',
            -parameters    => {
                'method_link_types' => $self->o('method_link_types'),
            },
            -input_ids     => [
                {
                    'compara_db'        => $self->o('compara_db'),
                    'mlss_id'           => $self->o('mlss_id'),
                },
            ],
            -flow_into      => {
                '2' => [ 'initJobs' ],
            },
            -rc_name => 'default_with_reg_conf',
        },

        {  -logic_name => 'initJobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs',

            -parameters => {'species' => $self->o('species'),
			    'dump_mlss_id' => $self->o('mlss_id'),
			    'output_dir' => $self->o('output_dir'),
			    'compara_db' => $self->o('compara_db'),
			    'maf_output_dir' => $self->o('maf_output_dir'), #define if want to run emf2maf 
			    'reg_conf' => $self->o('reg_conf'),
			    split_mode => $self->o('split_mode'),
			   },
            -flow_into => {
                $self->o('mode') eq 'file' ?
                (
                    '5->A' => [ 'dumpMultiAlign' ],
                ) : (
                    '2->A' => [ 'createChrJobs' ],
                    '3->A' => [ 'createSuperJobs' ],
                    '4->A' => [ 'createOtherJobs' ],
                ),
                '6->A' => [ 'copy_and_uncompress_emf_dir' ],
                'A->1' => [ 'md5sum'],
            },
            -rc_name => 'default_with_reg_conf',
            -wait_for       => 'create_tracking_tables',
        },
        # Generates DumpMultiAlign jobs from genomic_align_blocks on chromosomes (1 job per chromosome)
        {  -logic_name    => 'createChrJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs',
            -flow_into => {
                2 => [ 'dumpMultiAlign' ]
            },
            -rc_name => 'default_with_reg_conf',
        },
        # Generates DumpMultiAlign jobs from genomic_align_blocks on supercontigs (1 job per coordinate-system)
        {  -logic_name    => 'createSuperJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs',
            -flow_into => {
                2 => [ 'dumpMultiAlign' ]
            },
            -rc_name => 'default_with_reg_conf',
        },
        # Generates DumpMultiAlign jobs from genomic_align_blocks that do not contain $species
        {  -logic_name    => 'createOtherJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateOtherJobs',
            -parameters => {
                split_mode => $self->o('split_mode'),
            },
            -rc_name => 'crowd',
            -flow_into => {
                2 => [ 'dumpMultiAlign' ]
            },
            -rc_name => 'crowd_with_reg_conf',
        },
        {  -logic_name    => 'dumpMultiAlign',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign',
            -parameters    => {
                'cmd' => [ 'perl', '#dump_program#', '--species', '#species#', '--mlss_id', '#mlss_id#', '--masked_seq', $self->o('masked_seq'), '--split_size', '#split_size#', '--output_format', '#format#', '--output_file', '#output_dir#/#base_filename#.#region_name#.#format#' ],
                'output_file_pattern' => '#output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
                'reg_conf'      => $self->o('reg_conf'),
            },
            -hive_capacity => 50,
            -rc_name => 'crowd',
            $self->o('mode') eq 'tar' ? () : ( -flow_into => [ 'compress' ] ),
        },
        {   -logic_name     => 'copy_and_uncompress_emf_dir',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'cp -a #export_dir#/#base_filename#/#base_filename#*.emf* #output_dir#; gunzip #output_dir#/*.gz',
            },
            -flow_into      => [ 'find_emf_files' ],
        },
        {   -logic_name     => 'find_emf_files',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters     => {
                'inputcmd'      => 'grep -rc DATA #output_dir#/',
                'delimiter'     => ":",
                'column_names' => [ 'in_emf_file', 'num_blocks' ],
            },
            -flow_into => {
                $self->o('mode') eq 'tar' ? (
                    2 => [ 'emf2maf' ],     # will create a fan of jobs
                ) : (
                    '2->A' => [ 'emf2maf' ],     # will create a fan of jobs
                    'A->1' => [ 'compress_maf_dir' ]
                ),
            },
        },
        {   -logic_name     => 'emf2maf',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf',
            -analysis_capacity  => 5,
            -rc_name        => 'crowd',
        },
        {   -logic_name     => 'compress_maf_dir',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'gzip -f -9 #output_dir#/*.maf',
            },
        },
        {   -logic_name     => 'compress',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'gzip -f -9 #output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
            },
            -analysis_capacity => 1,
        },
        {   -logic_name     => 'md5sum',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'cd #output_dir#; md5sum *.#format#* > MD5SUM',
            },
            -flow_into      => [ 'readme' ],
        },
        {   -logic_name    => 'readme',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Readme',
            -parameters    => {
                'mode'  => $self->o('mode'),
                'readme_file' => '#output_dir#/README.#base_filename#',
            },
            $self->o('mode') eq 'tar' ? ( -flow_into => [ 'tar' ] ) : (),
            -rc_name => 'default_with_reg_conf',
        },
        {   -logic_name     => 'tar',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'           => 'cd #export_dir#; tar czf #base_filename#.tar.gz #base_filename#',
            },
        },
    ];
}

1;
