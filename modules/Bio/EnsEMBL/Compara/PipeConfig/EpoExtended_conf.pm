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

Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -species_set_name <species_set_name>

=head1 EXAMPLES

    # With GERP (mammals, sauropsids, fish):
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division vertebrates -species_set_name fish

    # Without GERP (primates):
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division vertebrates -species_set_name primates -run_gerp 0

=head1 DESCRIPTION

PipeConfig file for the EPO Extended (previously known as EPO-2X or EPO Low
Coverage) pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

    'pipeline_name' => $self->o('species_set_name').'_epo_extended_'.$self->o('rel_with_suffix'),
    'method_type'   => 'EPO_EXTENDED',

        'master_db' => 'compara_master',
        # Location of compara db containing EPO/EPO_EXTENDED alignment to use as a base
        'epo_db'    => $self->o('species_set_name') . '_epo',

        # Default location for pairwise alignments (can be a string or an array-ref,
        # and the database aliases can include '*' as a wildcard character)
        'pairwise_location' => [ qw(compara_prev lastz_batch_* unidir_lastz) ],

	'max_block_size'  => 1000000,                       #max size of alignment before splitting 

	 #gerp parameters
        'run_gerp' => 1,
	'gerp_window_sizes'    => [1,10,100,500],         #gerp window sizes

        #
        #Default statistics
        #
        'skip_multiplealigner_stats' => 0, #skip this module if set to 1
        'msa_stats_shared_dir' => $self->o('msa_stats_shared_basedir') . '/' . $self->o('species_set_name') . '/' . $self->o('ensembl_release'),

        'work_dir'   => $self->o('pipeline_dir'),
        'bed_dir' => $self->o('work_dir') . '/bed_dir/',
        'output_dir' => $self->o('work_dir') . '/feature_dumps/',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'output_dir', 'bed_dir']),
        $self->pipeline_create_commands_rm_mkdir(['msa_stats_shared_dir'], undef, 'do not rm'),
	   ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

            'master_db' => $self->o('master_db'),

            'run_gerp' => $self->o('run_gerp'),
            'genome_dumps_dir' => $self->o('genome_dumps_dir'),
            'msa_stats_shared_dir'  => $self->o('msa_stats_shared_dir'),
            'reg_conf' => $self->o('reg_conf'),
    };
}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended::pipeline_analyses_all($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    #'analysis[create_default_pairwise_mlss].param[base_location]={epo_pipeline_db_name}'
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-parameters'}->{'base_location'} = $self->o('epo_db');

    #'analysis[load_mlss_ids].param[add_sister_mlsss]=1'
    $analyses_by_name->{'load_mlss_ids'}->{'-parameters'}->{'add_sister_mlsss'} = 1;

    #'analysis[load_genomedb_factory].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'load_genomedb_factory'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[make_species_tree].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'make_species_tree'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[set_gerp_neutral_rate].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'set_gerp_neutral_rate'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[extended_genome_alignment].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'extended_genome_alignment'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[extended_genome_alignment_himem].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'extended_genome_alignment_himem'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[extended_genome_alignment_hugemem].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'extended_genome_alignment_hugemem'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[gerp].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'gerp'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[gerp_himem].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'gerp_himem'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[multiplealigner_stats_factory].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'multiplealigner_stats_factory'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[multiplealigner_stats].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'multiplealigner_stats'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[gab_factory].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'gab_factory'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[genome_db_factory].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'genome_db_factory'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[block_stats_aggregator].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'block_stats_aggregator'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[block_size_distribution].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'block_size_distribution'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';

    #'analysis[generate_msa_stats_report].param[mlss_id]=#ext_mlss_id#'
    $analyses_by_name->{'generate_msa_stats_report'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';
}

1;
