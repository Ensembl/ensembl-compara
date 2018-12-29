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

Bio::EnsEMBL::Compara::PipeConfig::EPO_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options, you will probably need to change the following :
        pipeline_db (-host)
        resource_classes

    'ensembl_cvs_root_dir' - the path to the compara/hive/ensembl GIT checkouts - set as an environment variable in your shell
        'password' - your mysql password
    'compara_anchor_db' - database containing the anchor sequences (entered in the anchor_sequence table)
    'compara_master' - location of your master db containing relevant info in the genome_db, dnafrag, species_set, method_link* tables
        The dummy values - you should not need to change these unless they clash with pre-existing values associated with the pairwise alignments you are going to use

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_conf.pm

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes

=head1 DESCRIPTION

    This configuaration file gives defaults for mapping (using exonerate at the moment) anchors to a set of target genomes (dumped text files)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

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

        # mlss_ids & co. Don't touch and define "mlss_id" on the command line
        # 'mlss_id' => 825, # epo mlss from master
        'ancestral_sequences_name' => 'ancestral_sequences',

        # Executable parameters
        'mapping_params'    => { bestn=>11, gappedextension=>"no", softmasktarget=>"no", percent=>75, showalignment=>"no", model=>"affine:local", },
        'enredo_params'     => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',
        'gerp_window_sizes' => [1,10,100,500], #gerp window sizes

        # Dump directory
        'enredo_output_file'    => $self->o('work_dir').'/enredo_output.txt',
        'bed_dir'               => $self->o('work_dir').'/bed',
        'feature_dir'           => $self->o('work_dir').'/feature_dump',
        'enredo_mapping_file'   => $self->o('work_dir').'/enredo_input.txt',
        'bl2seq_dump_dir'       => $self->o('work_dir').'/bl2seq', # location for dumping sequences to determine strand (for bl2seq)
        'bl2seq_file_stem'      => '#bl2seq_dump_dir#/bl2seq',
        'output_dir'            => '#feature_dir#', # alias

        # Options
        #skip this module if set to 1
        'skip_multiplealigner_stats' => 0,
        # dont dump the MT sequence for mapping
        'only_nuclear_genome' => 1,
        # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
        'add_non_nuclear_alignments' => 1,
         # batch size of grouped anchors to map
        'anchor_batch_size' => 500, #mammals
        #'anchor_batch_size' => 50,  #fish
         # max number of sequences to allow in an anchor
        'anc_seq_count_cut_off' => 15,
        # Usually set to 0 because we run Gerp on the EPO2X alignment instead
        'run_gerp' => 0,
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

        'mlss_id'                   => $self->o('mlss_id'),

        # directories
        'work_dir'              => $self->o('work_dir'),
        'feature_dir'           => $self->o('feature_dir'),
        'enredo_output_file'    => $self->o('enredo_output_file'),
        'bed_dir'               => $self->o('bed_dir'),
        'genome_dumps_dir'      => $self->o('genome_dumps_dir'),
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

        {   -logic_name => 'start_prepare_databases',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
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

    # Move "make_species_tree" right after "create_mlss_ss" and disconnect it from "reuse_anchor_align_factory"
    $analyses_by_name->{'create_mlss_ss'}->{'-flow_into'} = [ 'make_species_tree' ];
    delete $analyses_by_name->{'make_species_tree'}->{'-flow_into'};

    # Do "dump_mappings_to_file" after having trimmed the anchors
    $analyses_by_name->{'trim_anchor_align_factory'}->{'-flow_into'} = {
        '2->A' => $analyses_by_name->{'trim_anchor_align_factory'}->{'-flow_into'}->{2},
        'A->1' => [ 'dump_mappings_to_file' ],
    };
}

1;
