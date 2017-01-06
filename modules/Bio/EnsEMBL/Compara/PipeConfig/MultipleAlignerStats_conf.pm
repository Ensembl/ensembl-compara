=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf

=head1 DESCRIPTION

Pipeline that computes and stores statistics for a multiple alignment.

Note: This is usually embedded in all the multiple-alignment pipelines, but
is also available as a standalone pipeline in case the stats have to be
rerun or the alignment has been imported

=head1 SYNOPSIS

This pipeline requires two arguments: a compara database (to read the alignment
and store the stats) and a mlss_id.

The first analysis ("stats_factory") can be re-seeded with extra parameters to
compute stats on other alignments.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Dump location
        'dump_dir'      => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/alignerstats_'.$self->o('rel_with_suffix').'/',
        'bed_dir'       => $self->o('dump_dir').'bed_dir',
        'feature_dumps' => $self->o('dump_dir').'feature_dumps',

        # Executable locations
        'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'compare_beds_exe'  => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        'mkdir -p '.$self->o('bed_dir'),
        'mkdir -p '.$self->o('feature_dumps'),
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes}, # inherit 'default' from the parent class
        'mem3500' => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
    };
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}
sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},       # here we inherit anything from the base class
        'compara_db'    => $self->o('compara_db'),
    }
}



sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'stats_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -input_ids  => [
                {
                    'mlss_id'       => $self->o('mlss_id'),
                }
            ],
            -flow_into  => {
                '2->A' => [ 'multiplealigner_stats' ],
                'A->1' => [ 'block_size_distribution' ],
            },
        },

        {   -logic_name => 'multiplealigner_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
            -parameters => {
                'dump_features'     => $self->o('dump_features_exe'),
                'compare_beds'      => $self->o('compare_beds_exe'),
                'bed_dir'           => $self->o('bed_dir'),
                'ensembl_release'   => $self->o('ensembl_release'),
                'output_dir'        => $self->o('feature_dumps'),
            },
            -rc_name => 'mem3500',
        },

        {   -logic_name => 'block_size_distribution',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerBlockSize',
        },
    ];
}

1;
