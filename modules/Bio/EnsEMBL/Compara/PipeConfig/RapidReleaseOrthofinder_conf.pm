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

Bio::EnsEMBL::Compara::PipeConfig::RapidReleaseOrthofinder_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::RapidReleaseOrthofinder_conf -host mysql-ens-compara-prod-X -port XXXX \
        --species <species_name>

=head1 DESCRIPTION

The PipeConfig file for the pipeline that runs/updates Orthofinder results
for rapid release query genomes against a precomputed set of references.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::RapidReleaseOrthofinder_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'pipeline_name'     => 'rapid_orthofinder_' . $self->o('rel_with_suffix'),

        # Set mandatory databases
        'compara_db'   => $self->pipeline_url(),
        'output_db'    => $self->o('compara_db'),
        'member_db'    => $self->o('compara_db'),
        'ncbi_db'      => 'ncbi_taxonomy',
        'rr_ref_db'    => 'compara_references',
        'meta_host'    => 'mysql-ens-meta-prod-1',

        # List of species - should only contain one species however
        'species'       => [ ],
        'division'      => 'homology_annotation',

        # registry_file compatibility so can be overridden if necessary
        'registry_file' => $self->o('reg_conf'),

        # Member loading parameters - matches reference genome members
        'include_reference'           => 1,
        'include_nonreference'        => 0,
        'include_patches'             => 0,
        'store_coding'                => 1,
        'store_ncrna'                 => 0,
        'store_others'                => 0,
        'store_exon_coordinates'      => 0,
        'store_related_pep_sequences' => 0,
        'skip_dna'                    => 1,

        # Member HC parameters
        'allow_ambiguity_codes'         => 1,
        'only_canonical'                => 0,
        'allow_missing_cds_seqs'        => 1,
        'allow_missing_coordinates'     => 1,
        'allow_missing_exon_boundaries' => 1,

        # Directories to write to
        'work_dir'     => $self->o('pipeline_dir'),
        'dump_path'    => $self->o('work_dir'),

        # Cloud specific locations
        'cloud_end_url' => 'https://uk1s3.embassy.ebi.ac.uk',
        'cloud_bucket'  => 's3://RapidReleaseOrthofinder',

        # shared locations for orthofinder
        'shared_file_dir'   => $self->o('shared_hps_dir') . '/reference_fasta_symlinks/',
        'members_dumps_dir' => $self->o('shared_hps_dir') . '/rapid_genomes/',
        'results_dir'       => $self->o('shared_hps_dir') . '/orthofinder_results',

        # FTP locations
        'ftp_root' => '/nfs/production/flicek/ensembl/production/ensemblftp/',
        'ftp_dir'  => $self->o('ftp_root') . 'rapid_release/homologies/',

        #Orthfinder executable
        'orthofinder_exe' => '/hps/software/users/ensembl/ensw/C8-MAR21-sandybridge/linuxbrew/bin/orthofinder',
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'members_dumps_dir']),

    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'ncbi_db'       => $self->o('ncbi_db'),
    };
}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name      => 'core_species_factory',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesFactory',
            -max_retry_count => 1,
            -input_ids       => [{
                'registry_file'      => $self->o('registry_file'),
                'species_list'       => $self->o('species'),
            },],
            -flow_into       => {
                8 => [ 'backbone_fire_db_prepare' ],
            },
            -hive_capacity   => 1,
        },

        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'backbone_fire_orthofinder_prepare' ],
            },
        },

        {   -logic_name     => 'dump_full_fasta',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',
            -rc_name        => '1Gb_job',
            -hive_capacity  => 10,
        },

        {   -logic_name => 'backbone_fire_orthofinder_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                1 => [ 'orthofinder_factory' ],
            },
        },

        {   -logic_name => 'orthofinder_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::TaxonomicCollectionFactory',
            -parameters => {
                'shared_file_dir' => $self->o('cloud_bucket'),
            },
            -flow_into  => {
                1 => [ 'copy_collection_with_query' ],
            },
        },

        {   -logic_name => 'copy_collection_with_query',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'new_dir'  => $self->o('results_dir') . '/#species_name#_orig',
                'spec_dir' => $self->o('results_dir') . '/#species_name#',
                'cmd'      => 'mkdir #new_dir# && mkdir #temp_dir# && rsync -aW #collection_dir# #new_dir# && cp #fasta_file# #spec_dir#',
            },
            -flow_into => {
                1 => [ 'run_orthofinder' ],
            },
        },

        {   -logic_name => 'run_orthofinder',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'new_dir'         => $self->o('results_dir') . '/#species_name#_orig',
                'spec_dir'        => $self->o('results_dir') . '/#species_name#',
                'orthofinder_exe' => $self->o('orthofinder_exe'),
                'cmd'             => '#orthofinder_exe# -t 16 -a 8 -b #new_dir# -f #spec_dir#',
            },
            -rc_name    => '128Gb_16c_job',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers::pipeline_analyses_copy_ncbi_and_core_genome_db($self) },

    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'hc_members_per_genome'}->{'-flow_into'}->{1} = ['dump_full_fasta'];
}

1;
