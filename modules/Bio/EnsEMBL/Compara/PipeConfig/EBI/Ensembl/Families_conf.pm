
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

Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblFamilies_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. Ensure that LoadMembers pipeline have been run

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:

        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Families_conf \
        -password <your_password> -mlss_id <your_current_Family_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Families_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Families_conf');

sub default_options {

    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options },

        'division' => 'ensembl',

        # used by the StableIdMapper as the reference:
        'prev_rel_db' => 'compara_prev',

        # Once the members are loaded, it is fine to start the families pipeline
        'member_db' => 'compara_members',
        # used by the StableIdMapper as the location of the master 'mapping_session' table:
        'master_db' => 'compara_master', 

        'test_mode' => 1, #set this to 0 if this is production run. Prevents writing of the pipeline url into the master db unless it is A PRODUCTION run

        # HMM clustering
        #'hmm_clustering'      => 0,
        'hmm_clustering'      => 1,

        # data directories:
        'warehouse_dir' => '/nfs/production/panda/ensembl/warehouse/compara/production/'.$self->o('rel_with_suffix').'/',

        'blast_params' => '',    # By default C++ binary has composition stats on and -seg masking off

        # Thresholds for Mafft resource-classes
        'max_genes_lowmem_mafft'        =>  8000,
        'max_genes_singlethread_mafft'  => 50000,
        'max_genes_computable_mafft'    => 300000,

        # resource requirements:
        'blast_minibatch_size'    => 25,                         # we want to reach the 1hr average runtime per minibatch
        'blast_capacity'          => 5000,                       # work both as hive_capacity and resource-level throttle
        'mafft_capacity'          => 400,
        'cons_capacity'           => 100,
        'HMMer_classify_capacity' => 1500,

        'load_uniprot_members_from_member_db' => 1,
    };
} ## end sub default_options


1;

