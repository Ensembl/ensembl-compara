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

Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt1_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options, you will probably need to change the following :
        pipeline_db (-host)
        resource_classes 

        'password' - your mysql password
	'compara_pairwise_db' - I'm assuiming that all of your pairwise alignments are in one compara db
	'reference_genome_db_id' - the genome_db_id (ie the species) which is in all your pairwise alignments
	'list_of_pairwise_mlss_ids' - a comma separated string containing all the pairwise method_link_species_set_id(s) you wise to use to generate the anchors
	'main_core_dbs' - the servers(s) hosting most/all of the core (species) dbs
	'core_db_urls' - any additional core dbs (not in 'main_core_dbs')
        The dummy values - you should not need to change these unless they clash with pre-existing values associated with the pairwise alignments you are going to use

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt1_conf.pm

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes

=head1 DESCRIPTION  

    This configuaration file gives defaults for the first part of the EPO pipeline (this part generates the anchors from pairwise alignments). 

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt1_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_pt1_conf');

sub default_options {
    my ($self) = @_;

    return {
      	%{$self->SUPER::default_options},
      	   
        # connection parameters to various databases:
      	'pipeline_db' => { # the production database itself (will be created)
      		-host   => 'compara4',
          -driver => 'mysql',
      		-port   => 3306,
          -user   => 'ensadmin',
      		-pass   => $self->o('password'),
      		-dbname => $ENV{'USER'}.'_6fish_gen_anchors_'.$self->o('rel_with_suffix'),
         },

      	# database containing the pairwise alignments needed to get the overlaps
      	'compara_pairwise_db' => {
      		-user => 'ensro',
      		-port => 3306,
      		-host => 'ens-livemirror',
      		-driver => 'mysql',
      		-pass => '',
      		-dbname => 'ensembl_compara_72',
      	},

      	# location of most of the core dbs - to get the sequence from
        'main_core_dbs' => [
          {
            -user => 'ensro',
            -port => 3306,
            -host => 'ens-livemirror',
            -driver => 'mysql',
            -dbname => '',
            -db_version => $self->o('core_db_version'),
          },
        ],

        # any additional core dbs
        'additional_core_db_urls' => { 
            # 'gallus_gallus' => 'mysql://ensro@ens-staging1:3306/gallus_gallus_core_73_4',
        },  

      	# genome_db_id from which pairwise alignments will be used
      	'reference_genome_db_id' => 142,
      	'list_of_pairwise_mlss_ids' => "634,635,636",
      	  # location of species core dbs which were used in the pairwise alignments
      	'core_db_urls' => [ 'mysql://ensro@ens-livemirror:3306/72' ],
      	
      	'gerp_program_version' => "2.1",
      	'gerp_exe_dir' => "/software/ensembl/compara/gerp/GERPv2.1",
      	'exonerate' => '/software/ensembl/compara/exonerate/exonerate', # path to exonerate executable
        'ortheus_c_exe' => '/software/ensembl/compara/OrtheusC/bin/OrtheusC',
    };
}

1;
