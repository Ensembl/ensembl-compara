=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf

=head1 SYNOPSIS

    #0. This script is simply a pared-down version of Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf
        -- all the alignment steps have been removed but otherwise it is the same.

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. You may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. Make sure that all default_options are set correctly, especially:
        release
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        bed_dir

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf --dbname hsap_ggor_lastz_64 --password <your_password) --mlss_id 536 --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor_nib_files/ --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --password <your_password> --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    You will probably need to provide a registry configuration file pointing to pore and compara databases (--reg_conf).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

	# executable locations:
	'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
	'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",
	'create_pair_aligner_page_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl",

        #
	#Default pairaligner config
	#
	'bed_dir' => '/nfs/production/panda/ensemblgenomes/production/'.$ENV{USER}.'/pairaligner_stats/coding-region-stats',
	'output_dir' => '/nfs/production/panda/ensemblgenomes/production/'.$ENV{USER}.'/pairaligner_stats/coding-region-stats',
            
    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
            
        #Store CodingExon coverage statistics
        $self->db_cmd('CREATE TABLE IF NOT EXISTS statistics (
        method_link_species_set_id  int(10) unsigned NOT NULL,
        species_name                varchar(40) NOT NULL DEFAULT "",
        seq_region                  varchar(40) NOT NULL DEFAULT "",
        matches                     INT(10) DEFAULT 0,
        mis_matches                 INT(10) DEFAULT 0,
        ref_insertions              INT(10) DEFAULT 0,
        non_ref_insertions          INT(10) DEFAULT 0,
        uncovered                   INT(10) DEFAULT 0,
        coding_exon_length          INT(10) DEFAULT 0
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;'),

       'mkdir -p '.$self->o('output_dir'), #Make dump_dir directory
       'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
    ];
}


sub resource_classes {
    my ($self) = @_;

    return {
	    %{$self->SUPER::resource_classes}, # inherit 'default' from the parent class
	    '1Gb'   => { 'LSF' => '-M1000 -R"rusage[mem=1000]"' },
	   };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
	    { -logic_name => 'pairaligner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
	      -parameters => {
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'create_pair_aligner_page' => $self->o('create_pair_aligner_page_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'mlss_id'        => $self->o('mlss_id'),
			      'ensembl_release' => $self->o('release'),
			      'reg_conf' => $self->o('reg_conf'),
			      'output_dir' => $self->o('output_dir'),
			     },
                -input_ids => [{}],
              -flow_into => {
                              1 => [ 'coding_exon_stats_summary' ],
			      2 => [ 'coding_exon_stats' ],
			     },
	      -rc_name => '1Gb',
	    },
            {   -logic_name => 'coding_exon_stats',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats',
                -hive_capacity => 10,
                -rc_name => '1Gb',
            },
            {   -logic_name => 'coding_exon_stats_summary',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary',
		-parameters => {
				'mlss_id' => $self->o('mlss_id'),
				},
                -rc_name => '1Gb',
                -wait_for =>  [ 'coding_exon_stats' ],
            },
	   ];
}

1;
