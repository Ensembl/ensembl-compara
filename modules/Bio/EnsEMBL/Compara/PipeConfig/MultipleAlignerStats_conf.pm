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

The first analysis ("multiplealigner_stats_factory") can be re-seeded with extra parameters to
compute stats on other alignments.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

Example init : init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf -host mysql-ens-compara-prod-2.ebi.ac.uk:4522 -pipeline_name <> -compara_db <> -mlss_id <>

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Dump location
        'dump_dir'      => $self->o('pipeline_dir'),
        'bed_dir'       => $self->o('dump_dir').'bed_dir',
        'output_dir'    => $self->o('dump_dir').'feature_dumps',

        'msa_stats_shared_dir' => undef,
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['output_dir', 'bed_dir']),
        $self->pipeline_create_commands_rm_mkdir(['msa_stats_shared_dir'], undef, 'do not rm'),
    ];
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

        'msa_stats_shared_dir'=> $self->o('msa_stats_shared_dir'),
    }
}



sub core_pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats::pipeline_analyses_multiple_aligner_stats($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [
        {
            'mlss_id'       => $self->o('mlss_id'),
        }
    ];

    return $pipeline_analyses;
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'gab_factory'}->{'-parameters'}->{'db_conn'} = '#compara_db#';
    $analyses_by_name->{'genome_db_factory'}->{'-parameters'}->{'db_conn'} = '#compara_db#';
    $analyses_by_name->{'genome_length_fetcher'}->{'-parameters'}->{'db_conn'} = '#compara_db#';
}


1;
