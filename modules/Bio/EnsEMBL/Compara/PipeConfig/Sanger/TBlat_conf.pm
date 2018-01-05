=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options in PairAligner_conf.pm, especically:
        release
        pipeline_db (-host)
        resource_classes 

    #4. Check all default_options below, especially
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options

    #5. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf --dbname drer_onil_tblat_67 --password <your password> --mlss_id 574 --pipeline_db -host=compara1 --ref_species danio_rerio --pipeline_name TBLAT_dr_on_67

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    This configuaration file gives defaults specific for the translated blat net pipeline. It inherits from PairAligner_conf.pm and parameters here will over-ride the parameters in PairAligner_conf.pm. 
    Please see PairAligner_conf.pm for general details of the pipeline.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::TBlat_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

	    #Define location of core databases separately (over-ride curr_core_sources_locs in Pairwise_conf.pm)
#           'reference' => {
#               -host           => "host_name",
#               -port           => port,
#               -user           => "user_name",
#               -dbname         => "my_human_database",
#               -species        => "homo_sapiens"
#           },
#            'non_reference' => {
#                 -host           => "host_name",
#                 -port           => port,
#                 -user           => "user_name",
#                 -dbname         => "my_ciona_database",
#                 -species        => "ciona_intestinalis"
#               },
#	    'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
#	    'curr_core_sources_locs'=> '',

	    'ref_species' => 'homo_sapiens',

	    #directory to dump dna files. Note that 2 subdirectories will be appended to this, ${genome_db_id1}_${genome_db_id2}/species_name to
	    #ensure uniqueness across pipelines
	    'dump_dir' => '/lustre/scratch101/ensembl/' . $ENV{USER} . '/pair_aligner/dna_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

	    #Location of executables
	    'pair_aligner_exe' => '/software/ensembl/compara/bin/blat',

            # Capacities
            'filter_duplicates_hive_capacity' => 200,
            'filter_duplicates_batch_size' => 10,
            'pair_aligner_analysis_capacity' => 700,
            'pair_aligner_batch_size' => 40,
            'chain_hive_capacity' => 200,
            'chain_batch_size' => 10,
            'net_hive_capacity' => 300,
            'net_batch_size' => 10,

            #Resource requirements
            'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
            'aligner_capacity' => 2000,
	   };
}


sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'long'   => { 'LSF' => '-q long -C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'crowd' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1800,'.$self->o('dbresource').'=10:duration=3]"' },
            'crowd_himem' => { 'LSF' => '-C0 -M6000 -R"select[mem>6000 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=6000,'.$self->o('dbresource').'=10:duration=3]"' },
    };
}


1;
