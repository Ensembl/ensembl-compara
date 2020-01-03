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

Bio::EnsEMBL::Compara::PipeConfig::ImportPatchAlignmentsToRef_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportPatchAlignmentsToRef_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

Pipeline to import the alignments between patches / haplotypes and primary
regions. The original data are in the core database and only need to be
transformed into genomic_align(_block) entries.

The resulting database can be merged into the release database with copy_data.pl.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ImportPatchAlignmentsToRef_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # The master database
        'master_db'             => 'compara_master',

        # The method_link_type for this kind of alignments
        'lastz_patch_method'    => 'LASTZ_PATCH',
    };
}


# the $self->o() parameters that are needed by at least 2 analyses
sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'master_db'             => $self->o('master_db'),
        'lastz_patch_method'    => $self->o('lastz_patch_method'),
    }
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'find_lastz_patch_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',    # JobFactory is used to gather data from the database, but it will create a single job
            -input_ids  => [ {} ],
            -parameters => {
                'db_conn'               => '#master_db#',

                'inputquery'            => 'SELECT GROUP_CONCAT(CONCAT("--mlss ", method_link_species_set_id) SEPARATOR " ") AS mlss_ids FROM method_link_species_set JOIN method_link USING (method_link_id) WHERE method_link.type = "#lastz_patch_method#" AND first_release IS NOT NULL AND last_release IS NULL'
            },
            -rc_name    => '2Gb_job',
            -flow_into  => {
                2 => [ 'populate_new_database' ],
            },
        },

        {   -logic_name => 'populate_new_database',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'           => '#program# --master "#master_db#" --new "#pipeline_db#" --skip-data #mlss_ids#',
                'program'       => $self->o('populate_new_database_exe'),
                'pipeline_db'   => $self->pipeline_url(),      # I would like this to be generated at runtime
            },
            -rc_name   => '2Gb_job',
            -flow_into => [ 'genomedb_factory' ],
        },

        {   -logic_name => 'genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'extra_parameters'      => [ 'locator' ],
            },
            -rc_name   => '2Gb_job',
            -flow_into => {
                2 => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -rc_name    => '2Gb_job',
            -flow_into  => [ 'convert_patch_to_compara_align' ],
        },

        {   -logic_name => 'convert_patch_to_compara_align',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::ConvertPatchesToComparaAlign',
            -rc_name    => '2Gb_job',
            -flow_into  => [ 'update_max_alignment_length' ],
        },

        {   -logic_name => 'update_max_alignment_length',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
            -rc_name    => '2Gb_job',
        },
    ];
}

1;

