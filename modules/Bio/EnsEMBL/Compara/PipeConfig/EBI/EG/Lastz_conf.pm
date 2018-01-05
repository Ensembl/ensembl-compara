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

Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf

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
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::Lastz_conf --dbname hsap_btau_lastz_64 --password <your password> --mlss_id 534 --pipeline_db -host=compara1 --ref_species homo_sapiens --pipeline_name LASTZ_hs_bt_64 

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    This configuaration file gives defaults specific for the lastz net pipeline. It inherits from PairAligner_conf.pm and parameters here will over-ride the parameters in PairAligner_conf.pm. 
    Please see PairAligner_conf.pm for general details of the pipeline.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::Lastz_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Lastz_conf');  # Inherit from LastZ@EBI config file


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

            'host' => 'mysql-eg-prod-2.ebi.ac.uk',
            'port' => 4239,
            'user' => 'ensrw',
            'password' => $self->o('password'),

	    'pipeline_name'         => 'LASTZ_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

            'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',

            'staging_loc1' => {
                -host   => 'mysql-eg-staging-1.ebi.ac.uk',
                -port   => 4160,
                -user   => 'ensro',
                -pass   => '',
            },
            'staging_loc2' => {
                -host   => 'mysql-eg-staging-2.ebi.ac.uk',
                -port   => 4275,
                -user   => 'ensro',
                -pass   => '',
            },
             'prod_loc1' => {
                -host   => 'mysql-eg-prod-1.ebi.ac.uk',
                -port   => 4238,
                -user   => 'ensro',
                -pass   => '',
                -db_version => 74,
            },
            'livemirror_loc' => {
                -host   => 'mysql-eg-mirror.ebi.ac.uk',
                -port   => 4205,
                -user   => 'ensro',
                -pass   => '',
                -db_version => 73,
            },

            #'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
            'curr_core_sources_locs'    => [ $self->o('prod_loc1') ],
            'curr_core_dbs_locs'        => '', #if defining core dbs with config file. Define in Lastz_conf.pm or TBlat_conf.pm


	    #Alternatively, define location of core databases separately (over-ride curr_core_sources_locs in Pairwise_conf.pm)
	    #'reference' => {
	    #	-host           => "host_name",
	    #	-port           => port,
	    #	-user           => "user_name",
	    #	-dbname         => "my_human_database",
	    #	-species        => "homo_sapiens"
	    #   },
            #'non_reference' => {
	    #	    -host           => "host_name",
	    #	    -port           => port,
	    #	    -user           => "user_name",
	    #	    -dbname         => "my_bushbaby_database",
	    #	    -species        => "otolemur_garnettii"
	    #	  },
	    #'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
	    #'curr_core_sources_locs'=> '',

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
            'filter_duplicates_hive_capacity' => 200,
            'filter_duplicates_batch_size' => 10,

	   };
}

sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},
	    'default' => {'LSF' => '-q production-rh7'},
            '100Mb' => { 'LSF' => '-q production-rh7 -M100 -R"rusage[mem=100]"' },
	    '500Mb' => { 'LSF' => '-q production-rh7 -M500 -R"rusage[mem=500]"' },
            '1Gb'   => { 'LSF' => '-q production-rh7 -M1000 -R"rusage[mem=1000]"' },
            'crowd' => { 'LSF' => '-q production-rh7 -M1800 -R"rusage[mem=1800]"' },
            'crowd_himem' => { 'LSF' => '-q production-rh7 -M3600 -R"rusage[mem=3600]"' },
	    '4.2Gb' => { 'LSF' => '-q production-rh7 -M4200 -R"rusage[mem=4200]"' },
	    '8.4Gb' => { 'LSF' => '-q production-rh7 -M8400 -R"rusage[mem=8400]"' },
    };
}


sub pipeline_analyses {
    my $self = shift;
    my $all_analyses = $self->SUPER::pipeline_analyses(@_);
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'pairaligner_stats'         => 'crowd',
        'alignment_nets'            => 'crowd',
        'alignment_nets_himem'      => 'crowd_himem',
        'create_alignment_nets_jobs'=> 'crowd',
        'alignment_chains'          => '1Gb',
        'create_alignment_chains_jobs'  => 'crowd_himem',
        'create_filter_duplicates_jobs'     => 'crowd',
        'create_pair_aligner_jobs'  => 'crowd',
        'populate_new_database' => '8.4Gb',
        'parse_pair_aligner_conf' => '4.2Gb',
        'set_internal_ids_collection' => '1Gb',
        'store_sequence'        => '1Gb',
        'store_sequence_again'  => 'crowd_himem',
        $self->o('pair_aligner_logic_name') => 'crowd_himem',
        $self->o('pair_aligner_logic_name')."_himem1" => '8.4Gb',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }

    # Other parameters that have to be set
    $analyses_by_name{'store_sequence_again'}->{'-hive_capacity'} = 50;

    return $all_analyses;
}


1;
