
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

        #'mlss_id'         => 30047,                    # it is very important to check that this value is current (commented out to make it obligatory to specify)
        #'host'          => 'compara2',                 # where the pipeline database will be created
        'host'          => 'mysql-ens-compara-prod-2',        # where the pipeline database will be created
        'port'          => '4522',                      # server port

        'email'           => $self->o('ENV', 'USER').'@ebi.ac.uk',

        'division' => 'ensembl',
        'reg_conf'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/production_reg_'.$self->o('division').'_conf.pl',

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
        'hmm_library_basedir' => '/hps/nobackup2/production/ensembl/compara_ensembl/treefam_hmms/2018-08-20',

        # code directories:
        'blast_bin_dir'     => $self->check_dir_in_cellar('blast/2.2.30/bin'),
        'mcl_bin_dir'       => $self->check_dir_in_cellar('mcl/14-137/bin'),
        'mafft_root_dir'    => $self->check_dir_in_cellar('mafft/7.305'),
        'pantherScore_path' => $self->check_dir_in_cellar('pantherscore/1.03'),
        'hmmer2_home'       => $self->check_dir_in_cellar('hmmer2/2.3.2/bin'),

        # data directories:
        'work_dir'      => '/hps/nobackup2/production/ensembl/' . $self->o( 'ENV', 'USER' ) . '/family_pipeline/' . $self->o('pipeline_name'),
        'warehouse_dir' => '/nfs/production/panda/ensembl/warehouse/compara/production/'.$self->o('rel_with_suffix').'/',

        'blast_params' => '',    # By default C++ binary has composition stats on and -seg masking off

        # Thresholds for Mafft resource-classes
        'max_genes_lowmem_mafft'        =>  8000,
        'max_genes_singlethread_mafft'  => 50000,
        'max_genes_computable_mafft'    => 300000,

        # resource requirements:
        'blast_minibatch_size'    => 25,                         # we want to reach the 1hr average runtime per minibatch
        'blast_gigs'              => 4,
        'blast_hm_gigs'           => 6,
        'mcl_gigs'                => 72,
        'mcl_threads'             => 12,
        'mafft_threads'           => 8,
        'lomafft_gigs'            => 4,
        'himafft_gigs'            => 64,
        'humafft_gigs'            => 96,
        'blast_capacity'          => 5000,                       # work both as hive_capacity and resource-level throttle
        'mafft_capacity'          => 400,
        'cons_capacity'           => 100,
        'HMMer_classify_capacity' => 1500,

        'load_uniprot_members_from_member_db' => 1,
    };
} ## end sub default_options

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{ $self->SUPER::resource_classes },    # inherit 'default' from the parent class

        'default'     => { 'LSF' => ['-M100   -R"select[mem>100]   rusage[mem=100]"', $reg_requirement] },
        'urgent'      => { 'LSF' => ['-M100   -R"select[mem>100]   rusage[mem=100]"', $reg_requirement] },
        'RegBlast'    => { 'LSF' => [ '-C0 -M' . $self->o('blast_gigs') . '000 -R"select[mem>'. $self->o('blast_gigs') . '000] rusage[mem=' . $self->o('blast_gigs') . '000]"', "-lifespan 360 $reg_requirement" ] },
        'LongBlastHM' => { 'LSF' => [ '-C0 -M' . $self->o('blast_hm_gigs') . '000 -R"select[mem>' .  $self->o('blast_hm_gigs') . '000] rusage[mem=' . $self->o('blast_hm_gigs') . '000]"', "-lifespan 1440 $reg_requirement" ] },
        'BigMcxload'  => { 'LSF' => ['-C0 -M' . $self->o('mcl_gigs') . '000 -R"select[mem>' . $self->o('mcl_gigs') . '000] rusage[mem=' . $self->o('mcl_gigs') . '000]"', $reg_requirement] },
        'BigMcl'      => { 'LSF' => ['-C0 -M' . $self->o('mcl_gigs') . '000 -n ' . $self->o('mcl_threads') . ' -R"select[ncpus>=' . $self->o('mcl_threads') . ' && mem>' .  $self->o('mcl_gigs') . '000] rusage[mem=' . $self->o('mcl_gigs') . '000] span[hosts=1]"', $reg_requirement] },
        'BigMafft'    => { 'LSF' => ['-C0 -M'.$self->o('himafft_gigs').'000', $reg_requirement] },
        'LoMafft'     => { 'LSF' => ['-C0 -M' . $self->o('lomafft_gigs') . '000 -R"select[mem>' . $self->o('lomafft_gigs') . '000] rusage[mem=' . $self->o('lomafft_gigs') . '000]"', $reg_requirement] },
        '250Mb_job'   => { 'LSF' => ['-C0 -M250 -R"select[mem>250] rusage[mem=250]"', $reg_requirement] },
        '500MegMem'   => { 'LSF' => ['-C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement] },
        '2GigMem'     => { 'LSF' => ['-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"', $reg_requirement] }, 
        '4GigMem'     => { 'LSF' => ['-C0 -M4000 -R"select[mem>4000] rusage[mem=4000]"', $reg_requirement] },
        '8GigMem'     => { 'LSF' => ['-C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"', $reg_requirement] }, 
        '16GigMem'    => { 'LSF' => ['-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"', $reg_requirement] },

        'HugeMafft_multi_core' => { 'LSF' => '-C0 -M' . $self->o('humafft_gigs') . '000 -n ' . $self->o('mafft_threads') . ' -R"span[hosts=1]"' },

    };
}

1;

