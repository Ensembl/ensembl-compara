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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt3_conf

=head1 DESCRIPTION

    The PipeConfig file for the last part (3rd part) of the EPO pipeline. 
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
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt3_conf -mlss_id <your_current_epo_mlss_id> -species_set_name <the name of the species set> -compara_mapped_anchor_db <db name from epo_pt2 pipeline> -host <server_name> -port <server_port>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt3_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_pt3_conf');

sub default_options {
 my ($self) = @_;

    return {
      %{$self->SUPER::default_options},

      # Used to name the databases and the working directory
      #'species_set_name' => 'primates',

      # Where the pipeline lives
      #'host' => 'mysql-ens-compara-prod-3.ebi.ac.uk',
      #'port' => 4523,

      'division' => 'ensembl',

      # Dump directory
      'dump_dir' => $self->o('pipeline_dir'),

      # The ancestral_db is created on the same server as the pipeline_db
      'ancestral_db' => { # core ancestral db
          -driver   => $self->o('pipeline_db', '-driver'),
          -host     => $self->o('pipeline_db', '-host'),
          -port     => $self->o('pipeline_db', '-port'),
          -species  => $self->o('ancestral_sequences_name'),
          -user     => $self->o('pipeline_db', '-user'),
          -pass     => $self->o('pipeline_db', '-pass'),
          -dbname   => $self->o('dbowner').'_'.$self->o('species_set_name').'_ancestral_core_'.$self->o('rel_with_suffix'),
      },

      # master db
      'master_db' => 'compara_master',

    }; 

}

1;
