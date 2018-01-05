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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt3_conf

=head1 DESCRIPTION

    The Sanger-specific PipeConfig file for the last part (3rd part) of the EPO pipeline. 
    This will genereate the multiple sequence alignments (MSA) from a database containing a
    set of anchor sequences mapped to a set of target genomes. The pipeline runs Enredo 
    (which generates a graph of the syntenic regions of the target genomes) 
    and then runs Ortheus (which runs Pecan for generating the MSA) and infers 
    ancestral genome sequences. Finally Gerp may be run to generate constrained elements and 
    conservation scores from the MSA

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt3_conf -password <your_password> -mlss_id <your_current_epo_mlss_id> -species_set_name <the name of the species set> -compara_mapped_anchor_db <db name from epo_pt2 pipeline> -compara_master <>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt3_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_pt3_conf');

sub default_options {
 my ($self) = @_;

   return {
      %{$self->SUPER::default_options},

      'species_set_name' => 'primates',

      # Where the pipeline lives
      'host'  => 'compara5',

      'bl2seq' => '/software/ensembl/compara/bl2seq', # location of ncbi bl2seq executable on farm3
      'blastn' => undef,
      'enredo_exe' => '/software/ensembl/compara/enredo', # location of enredo executable
      
      # Dump directory
      'dump_dir' => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/epo/'.$self->o('species_set_name').'_'.$self->o('rel_with_suffix').'/',
      
      'pecan_jar' => '/software/ensembl/compara/pecan/pecan_v0.8.jar',
      'gerp_version' => '2.1', #gerp program version
      'gerp_exe_dir'    => '/software/ensembl/compara/gerp/GERPv2.1', #gerp program
      'epo_stats_report_email' => $ENV{'USER'} . '@sanger.ac.uk',

      # connection parameters to various databases:
    	'ancestral_db' => { # core ancestral db
    		-driver => 'mysql',
    		-host   => 'compara4',
    		-port   => 3306,
    		-species => $self->o('ancestral_sequences_name'),
    		-user   => 'ensadmin',
    		-pass   => $self->o('password'),
    		-dbname => $self->o('ENV', 'USER').'_'.$self->o('species_set_name').'_ancestral_core_'.$self->o('rel_with_suffix'),
    	},
    	# master db
      'compara_master' => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
    	# anchor mappings
      'compara_mapped_anchor_db' => 'mysql://ensro@compara5/wa2_primates_epo_anchor_mapping',

    }; 
}

1;
