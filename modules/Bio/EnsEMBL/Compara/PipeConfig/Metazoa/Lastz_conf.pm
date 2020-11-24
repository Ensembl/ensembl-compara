=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Lastz_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #4. Check all default_options below, especially
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options

    #5. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Lastz_conf \
          -host XXX -port XXX -user XXX -password XXX \
          -hive_force_init 1 \
          -reg_conf $REG_FILE \
          -pipeline_name "$tag" \
          -master_db $COMPARA_MASTER_URL_W \
          -ensembl_cvs_root_dir $ENSEMBL_ROOT_DIR \
          -do_compare_to_previous_db 0 \
          -mlss_id_list "[mlss_id_1,mlss_id_2,...,mlss_id_N]"

    #6. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl

=head1 DESCRIPTION  

This is a Metazoa configuration file for LastZ pipeline.
This pipeline inherits from Lastz_conf (which, in turn, inherits from PairAligner_conf.pm).
Please see Lastz_conf.pm and PairAligner_conf.pm for general details of the pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Lastz_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');


sub default_options {
my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'division'  => 'metazoa',
        # healthcheck
        'do_compare_to_previous_db' => 0,
        # Net
        'bidirectional' => 1,
    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'alignment_nets'            => '2Gb_job',
        'create_alignment_nets_jobs'=> '2Gb_job',
        'create_alignment_chains_jobs'  => '4Gb_job',
        'create_filter_duplicates_jobs'     => '2Gb_job',
        'create_pair_aligner_jobs'  => '2Gb_job',
        'populate_new_database' => '8Gb_job',
        'parse_pair_aligner_conf' => '4Gb_job',
        $self->o('pair_aligner_logic_name') => '4Gb_job',
        $self->o('pair_aligner_logic_name')."_himem1" => '8Gb_job',
    );

    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}


1;
