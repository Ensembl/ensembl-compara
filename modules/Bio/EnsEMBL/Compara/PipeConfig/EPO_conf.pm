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

Bio::EnsEMBL::Compara::PipeConfig::EPO_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -species_set_name <species_set_name>

=head1 DESCRIPTION

This PipeConfig file gives defaults for mapping (using exonerate at the moment)
anchors to a set of target genomes (dumped text files).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPO_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => $self->o('species_set_name').'_epo_'.$self->o('rel_with_suffix'),
        'method_type'   => 'EPO',

        # Databases
        'compara_master'    => 'compara_master',
        # Database containing the anchors for mapping
        'compara_anchor_db' => $self->o('species_set_name') . '_epo_anchors',
        # The previous database to reuse the anchor mappings
        'reuse_db'          => $self->o('species_set_name') . '_epo_prev',

        # The ancestral_db is created on the same server as the pipeline_db
        'ancestral_db' => {
            -driver   => $self->o('pipeline_db', '-driver'),
            -host     => $self->o('pipeline_db', '-host'),
            -port     => $self->o('pipeline_db', '-port'),
            -species  => $self->o('ancestral_sequences_name'),
            -user     => $self->o('pipeline_db', '-user'),
            -pass     => $self->o('pipeline_db', '-pass'),
            -dbname   => $self->o('dbowner').'_'.$self->o('species_set_name').'_ancestral_core_'.$self->o('rel_with_suffix'),
        },

        'ancestral_sequences_name' => 'ancestral_sequences',
        'ancestral_sequences_display_name' => 'Ancestral sequences',

        # Executable parameters
        'mapping_params'    => { bestn=>11, gappedextension=>"no", softmasktarget=>"no", percent=>75, showalignment=>"no", model=>"affine:local", },
        'enredo_params'     => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',
        'gerp_window_sizes' => [1,10,100,500], #gerp window sizes

        # Dump directory
        'work_dir'              => $self->o('pipeline_dir'),
        'enredo_output_file'    => $self->o('work_dir').'/enredo_output.txt',
        'bed_dir'               => $self->o('work_dir').'/bed',
        'feature_dir'           => $self->o('work_dir').'/feature_dump',
        'enredo_mapping_file'   => $self->o('work_dir').'/enredo_input.txt',
        'bl2seq_dump_dir'       => $self->o('work_dir').'/bl2seq', # location for dumping sequences to determine strand (for bl2seq)
        'bl2seq_file_stem'      => '#bl2seq_dump_dir#/bl2seq',
        'output_dir'            => '#feature_dir#', # alias

        # Options
        # Avoid reusing any species?
        'do_not_reuse_list'          => undef,
        #skip this module if set to 1
        'skip_multiplealigner_stats' => 0,
        # dont dump the MT sequence for mapping
        'only_nuclear_genome' => 1,
        # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
        'add_non_nuclear_alignments' => 1,
         # batch size of anchor sequences to map
        'anchor_batch_size' => 1000,
        # Usually set to 0 because we run Gerp on the EPO2X alignment instead
        'run_gerp' => 0,

        # Capacities
        'low_capacity'                 => 10,
        'map_anchors_batch_size'       => 5,
        'map_anchors_capacity'         => 2000,
        'trim_anchor_align_batch_size' => 20,
        'trim_anchor_align_capacity'   => 500,

        # MSA stats options
        'msa_stats_shared_dir' => $self->o('msa_stats_shared_basedir') . '/' . $self->o('species_set_name') . '/' . $self->o('ensembl_release'),
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'bed_dir', 'feature_dir', 'bl2seq_dump_dir']),
    ];
}


sub pipeline_wide_parameters {
    my $self = shift @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        # directories
        'work_dir'              => $self->o('work_dir'),
        'feature_dir'           => $self->o('feature_dir'),
        'enredo_output_file'    => $self->o('enredo_output_file'),
        'bed_dir'               => $self->o('bed_dir'),
        'genome_dumps_dir'      => $self->o('genome_dumps_dir'),
        'msa_stats_shared_dir'  => $self->o('msa_stats_shared_dir'),
        'enredo_mapping_file'   => $self->o('enredo_mapping_file'),
        'bl2seq_dump_dir'       => $self->o('bl2seq_dump_dir'),
        'bl2seq_file_stem'      => $self->o('bl2seq_file_stem'),

        # databases
        'compara_anchor_db' => $self->o('compara_anchor_db'),
        'master_db'         => $self->o('compara_master'),
        'reuse_db'          => $self->o('reuse_db'),
        'ancestral_db'      => $self->o('ancestral_db'),

        # options
        'run_gerp' => $self->o('run_gerp'),
    };

}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'load_mlss_id',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -parameters => {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('species_set_name'),
                'release'          => $self->o('ensembl_release'),
            },
            -input_ids  => [{}],
            -flow_into  => {
                '1->A' => [ 'copy_table_factory', 'set_internal_ids', 'drop_ancestral_db' ],
                'A->1' => 'reuse_anchor_align_factory',
            }
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors::pipeline_analyses_epo_anchor_mapping($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment::pipeline_analyses_epo_alignment($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    # Move "make_species_tree" right after "create_mlss_ss" and disconnect it from "dump_mappings_to_file"
    $analyses_by_name->{'create_mlss_ss'}->{'-flow_into'} = [ 'make_species_tree' ];
    $analyses_by_name->{'make_species_tree'}->{'-flow_into'} = WHEN( '#run_gerp#' => [ 'set_gerp_neutral_rate' ] );
    delete $analyses_by_name->{'set_gerp_neutral_rate'}->{'-flow_into'}->{1};

    # Do "dump_mappings_to_file" after having trimmed the anchors
    $analyses_by_name->{'trim_anchor_align_factory'}->{'-flow_into'} = {
        '2->A' => $analyses_by_name->{'trim_anchor_align_factory'}->{'-flow_into'}->{2},
        'A->1' => [ 'dump_mappings_to_file' ],
    };
}

1;
