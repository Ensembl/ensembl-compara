
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

Bio::EnsEMBL::Compara::PipeConfig::Sanger::Families_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Sanger::Families_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::Families_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Families_conf');

sub default_options {

    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options },

        #'mlss_id'         => 30047,         # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'host'          => 'compara2',                                          # where the pipeline database will be created
        'file_basename' => 'metazoa_families_' . $self->o('rel_with_suffix'),

        'email'           => $self->o('ENV', 'USER').'@sanger.ac.uk',

        # HMM clustering
        #'hmm_clustering'      => 0,
        'hmm_clustering'      => 1,
        'hmm_library_basedir' => '/lustre/scratch110/ensembl/mp14/multi_division_hmm_lib',
        'pantherScore_path'   => '/software/ensembl/compara/pantherScore1.03',
        'hmmer2_home'         => '/software/ensembl/compara/hmmer-2.3.2/src/',

        # code directories:
        'blast_bin_dir'  => '/software/ensembl/compara/ncbi-blast-2.2.30+/bin',
        'mcl_bin_dir'    => '/software/ensembl/compara/mcl-14-137/bin',
        'mafft_root_dir' => '/software/ensembl/compara/mafft-7.221',

        # data directories:
        'work_dir'      => '/lustre/scratch110/ensembl/' . $self->o( 'ENV', 'USER' ) . '/' . $self->o('pipeline_name'),
        'warehouse_dir' => '/warehouse/ensembl05/' . $self->o( 'ENV', 'USER' ) . '/families/',            # ToDo: move to a Compara-wide warehouse location

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
        'himafft_gigs'            => 14,
        'humafft_gigs'            => 96,
        'dbresource'              => 'my' . $self->o('host'),    # will work for compara1..compara5, but will have to be set manually otherwise
        'blast_capacity'          => 5000,                       # work both as hive_capacity and resource-level throttle
        'mafft_capacity'          => 400,
        'cons_capacity'           => 100,
        'HMMer_classify_capacity' => 100,

        # used by the StableIdMapper as the reference:
        'prev_rel_db' => 'mysql://ensro@ens-livemirror/ensembl_compara_#expr( #ensembl_release# - 1)expr#',

        # Protein Tree database
        'protein_trees_db' => 'mysql://ensadmin:' . $self->o('password') . '@compara4/wa2_protein_trees_87',

        # used by the StableIdMapper as the location of the master 'mapping_session' table:
        'master_db' => 'mysql://ensadmin:' . $self->o('password') . '@compara1/mm14_ensembl_compara_master', };
} ## end sub default_options

sub resource_classes {
    my ($self) = @_;
    return {
        %{ $self->SUPER::resource_classes },    # inherit 'default' from the parent class

        'urgent'   => { 'LSF' => '-q yesterday' },
        'RegBlast' => { 'LSF' => [ '-C0 -M' . $self->o('blast_gigs') . '000 -q normal -R"select[' . $self->o('dbresource') . '<' . $self->o('blast_capacity') . ' && mem>' .
                                     $self->o('blast_gigs') . '000] rusage[' . $self->o('dbresource') . '=10:duration=10:decay=1, mem=' . $self->o('blast_gigs') . '000]"',
                                   '-lifespan 360' ] },
        'LongBlastHM' => { 'LSF' => [ '-C0 -M' . $self->o('blast_hm_gigs') . '000 -q long -R"select[' . $self->o('dbresource') . '<' . $self->o('blast_capacity') . ' && mem>' .
                                        $self->o('blast_hm_gigs') . '000] rusage[' . $self->o('dbresource') . '=10:duration=10:decay=1, mem=' . $self->o('blast_hm_gigs') . '000]"',
                                      '-lifespan 1440' ] },
        'BigMcxload' => { 'LSF' => '-C0 -M' . $self->o('mcl_gigs') . '000 -q hugemem -R"select[mem>' . $self->o('mcl_gigs') . '000] rusage[mem=' . $self->o('mcl_gigs') . '000]"' },
        'BigMcl'     => {
                      'LSF' => '-C0 -M' . $self->o('mcl_gigs') . '000 -n ' . $self->o('mcl_threads') . ' -q hugemem -R"select[ncpus>=' . $self->o('mcl_threads') . ' && mem>' .
                        $self->o('mcl_gigs') . '000] rusage[mem=' . $self->o('mcl_gigs') . '000] span[hosts=1]"' },
        'BigMafft'   => { 'LSF' => '-C0 -M'.$self->o('himafft_gigs').'000 -q long -R"select['.$self->o('dbresource').'<'.$self->o('mafft_capacity').' && mem>'.$self->o('himafft_gigs').'000] rusage['.$self->o('dbresource').'=10:duration=10:decay=1, mem='.$self->o('himafft_gigs').'000]"' },
        'HugeMafft_multi_core' => { 'LSF' => '-C0 -M' . $self->o('humafft_gigs') . '000 -n ' . $self->o('mafft_threads') . ' -q long -R"select[' . $self->o('dbresource') . '<' . $self->o('mafft_capacity') . ' && mem>' .
                          $self->o('humafft_gigs') . '000] rusage[' . $self->o('dbresource') . '=10:duration=10:decay=1, mem=' . $self->o('humafft_gigs') . '000] span[hosts=1]"' },
        'LoMafft' => {
               'LSF' => '-C0 -M' . $self->o('lomafft_gigs') . '000 -R"select[' . $self->o('dbresource') . '<' . $self->o('mafft_capacity') . ' && mem>' . $self->o('lomafft_gigs') .
                 '000] rusage[' . $self->o('dbresource') . '=10:duration=10:decay=1, mem=' . $self->o('lomafft_gigs') . '000]"' },

        '500MegMem' => { 'LSF' => '-C0 -M500 -R"select[mem>500] rusage[mem=500]"' },
        '1GigMem' => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
        '2GigMem' => { 'LSF' => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
        '4GigMem' => { 'LSF' => '-C0 -M4000 -R"select[mem>4000] rusage[mem=4000]"' },
        '8GigMem' => { 'LSF' => '-C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"' },
        '16GigMem' => { 'LSF' => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
    };
}

1;

