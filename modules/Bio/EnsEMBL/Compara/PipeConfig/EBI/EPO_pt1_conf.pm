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

Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt1_conf

=head1 SYNOPSIS

    EBI-specific configuration for the EPO_pt1 pipeline. Options to check before
    initializing the pipeline:

      'password' - your mysql password
	    'compara_pairwise_db' - I'm assuiming that all of your pairwise alignments are in one compara db
	    'reference_genome_db_id' - the genome_db_id (ie the species) which is in all your pairwise alignments
	    'list_of_pairwise_mlss_ids' - a comma separated string containing all the pairwise method_link_species_set_id(s) you wise to use to generate the anchors
	    
      'main_core_dbs' - the servers(s) hosting most/all of the core (species) dbs
	    'core_db_urls' - any additional core dbs (not in 'main_core_dbs')

    #1. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt1_conf.pm

    #2. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

=head1 DESCRIPTION  

    This configuaration file gives defaults for the first part of the EPO pipeline (this part generates the anchors from pairwise alignments). 

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt1_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_pt1_conf');

sub default_options {
    my ($self) = @_;

    return {
      	%{$self->SUPER::default_options},

        # set up for birds 
        'species_set_name' => 'sauropsids',
        'reference_genome_db_id' => 157,
        'list_of_pairwise_mlss_ids' => "809,816,817",
        #location of full species tree, will be pruned
        'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.ensembl.branch_len.nw',


        # connection parameters to various databases:
      	'pipeline_db' => { # the production database itself (will be created)
        		-host   => 'mysql-ens-compara-prod-1.ebi.ac.uk',
            -driver => 'mysql',
        		-port   => 4485,
            -user   => 'ensadmin',
        		-pass   => $self->o('password'),
        		-dbname => $ENV{'USER'}.'_'.$self->o('pipeline_name'),
        },
      	  
        # database containing the pairwise alignments needed to get the overlaps
      	'compara_pairwise_db' => {
        		-user => 'ensro',
        		-port => 4485,
        		-host => 'mysql-ens-compara-prod-1.ebi.ac.uk',
        		-driver => 'mysql',
        		-pass => '',
        		-dbname => 'ensembl_compara_' . $self->o('core_db_version'),
      	},
      	# location of most of the core dbs - to get the sequence from
        'main_core_dbs' => [
            {
                -user => 'ensro',
                -port => 4240,
                -host => 'mysql-ensembl-mirror.ebi.ac.uk',
                -driver => 'mysql',
                -dbname => '',
                -db_version => $self->o('core_db_version'),
            },
        ],
          
        # any additional core dbs
        'additional_core_db_urls' => { 
            # 'gallus_gallus' => 'mysql://ensro@mysql-ens-sta-1.ebi.ac.uk:4519/gallus_gallus_core_88_5',
        },  

      	
      	# location of species core dbs which were used in the pairwise alignments
      	'core_db_urls' => [ 'mysql://ensro@mysql-ensembl-mirror.ebi.ac.uk:4240/'.$self->o('core_db_version') ],
      	'gerp_program_version' => "2.1",
        'gerp_exe_dir'    => $self->check_dir_in_cellar('gerp/20080211_1/bin'), #gerp program
        'pecan_exe_dir'   => $self->check_dir_in_cellar('pecan/0.8.0/libexec'),
        'java_exe'        => $self->check_exe_in_linuxbrew_opt('jdk@8/bin/java'),
        'exonerate_exe'   => $self->check_exe_in_cellar('exonerate22/2.2.0/bin/exonerate'), # path to exonerate executable
        'ortheus_c_exe'   => $self->check_exe_in_cellar('ortheus/0.5.0_1/bin/ortheus_core'),
        'ortheus_py'      => $self->check_exe_in_cellar('ortheus/0.5.0_1/bin/Ortheus.py'),
        'ortheus_lib_dir' => $self->check_dir_in_cellar('ortheus/0.5.0_1'),
        'semphy_exe'      => $self->check_exe_in_cellar('semphy/2.0b3/bin/semphy'),
        'estimate_tree_exe' => $self->check_file_in_cellar('pecan/0.8.0/libexec/bp/pecan/utils/EstimateTree.py'),
    };
}



1;
