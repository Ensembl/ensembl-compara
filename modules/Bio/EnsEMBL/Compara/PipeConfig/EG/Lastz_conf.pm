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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EG::Lastz_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. Check all default_options below, especially
        ref_species (if not homo_sapiens)
        default_chunks
        pair_aligner_options

    #3. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EG::Lastz_conf -host mysql-ens-compara-prod-X -port XXXX \
            -mlss_id 534 -ref_species homo_sapiens

    #4. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

This is a Ensembl Genomes configuration file for LastZ pipeline. Please, refer
to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EG::Lastz_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

            'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',

	    #Reference species
#	    'ref_species' => 'homo_sapiens',
	    'ref_species' => '',

            # healthcheck
            'do_compare_to_previous_db' => 0,
            # Net
            'bidirectional' => 1,

            #directory to dump nib files
            'dump_dir' => '/nfs/panda/ensemblgenomes/production/compara/' . $ENV{USER} . '/pair_aligner/' . $self->o('pipeline_name') . '/' . $self->o('host') . '/',
            #'bed_dir' => '/nfs/ensembl/compara/dumps/bed/',
            'bed_dir' => '/nfs/panda/ensemblgenomes/production/compara/' . $ENV{USER} . '/pair_aligner/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',
            'output_dir' => '/nfs/panda/ensemblgenomes/production/compara' . $ENV{USER} . '/pair_aligner/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',

            # Capacities
            'pair_aligner_analysis_capacity' => 100,
            'pair_aligner_batch_size' => 3,
            'chain_hive_capacity' => 50,
            'chain_batch_size' => 5,
            'net_hive_capacity' => 20,
            'net_batch_size' => 1,
	   };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
          'alignment_nets'                                => '2Gb_job',
          'create_alignment_nets_jobs'                    => '2Gb_job',
          'create_alignment_chains_jobs'                  => '4Gb_job',
          'create_filter_duplicates_jobs'                 => '2Gb_24_hour_job',
          'create_pair_aligner_jobs'                      => '2Gb_job',
          'populate_new_database'                         => '8Gb_job',
          'parse_pair_aligner_conf'                       => '4Gb_job',
          $self->o('pair_aligner_logic_name')             => '4Gb_24_hour_job',
          $self->o('pair_aligner_logic_name') . "_himem"  => '8Gb_24_hour_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}


1;
