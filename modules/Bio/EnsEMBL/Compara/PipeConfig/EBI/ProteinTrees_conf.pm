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

  Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf

=head1 DESCRIPTION

    Shared configuration options for ProteinTrees pipeline at the EBI


=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details
        'email'                 => $self->o('ENV', 'USER').'@ebi.ac.uk',
        'base_dir'              => '/hps/nobackup/production/ensembl/' . $self->o('ENV', 'USER') . '/protein_trees/',

    # executable locations:
        'hcluster_exe'              => $self->check_exe_in_cellar('hclustersg/0.5.0/bin/hcluster_sg'),
        'mcoffee_home'              => $self->check_dir_in_cellar('t-coffee/9.03.r1336'),
        'mafft_home'                => $self->check_dir_in_cellar('mafft/7.305'),
        'extaligners_exe_dir'       => $self->o('linuxbrew_home').'/bin/',   # We expect the latest version of each aligner to be symlinked there
        'trimal_exe'                => $self->check_exe_in_cellar('trimal/1.4.1/bin/trimal'),
        'noisy_exe'                 => $self->check_exe_in_cellar('noisy/1.5.12/bin/noisy'),
        'prottest_jar'              => $self->check_file_in_cellar('prottest3/3.4.2/libexec/prottest-3.4.2.jar'),
        'treebest_exe'              => $self->check_exe_in_cellar('treebest/88/bin/treebest'),
        'raxml_pthread_exe_sse3'    => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-SSE3'),
        'raxml_pthread_exe_avx'     => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-AVX'),
        'raxml_exe_sse3'            => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-SSE3'),
        'raxml_exe_avx'             => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-AVX'),
        'examl_exe_avx'             => $self->check_exe_in_cellar('examl/3.0.17/bin/examl-AVX'),
        'examl_exe_sse3'            => $self->check_exe_in_cellar('examl/3.0.17/bin/examl'),
        'parse_examl_exe'           => $self->check_exe_in_cellar('examl/3.0.17/bin/parse-examl'),
        'mpirun_exe'                => $self->check_exe_in_cellar('open-mpi/2.1.1/bin/mpirun'),
        'notung_jar'                => $self->check_file_in_cellar('notung/2.6.0/libexec/Notung-2.6.jar'),
        'treerecs_exe'              => '/homes/mateus/reconcile/Treerecs/bin/Treerecs',
        'quicktree_exe'             => $self->check_exe_in_cellar('quicktree/2.1/bin/quicktree'),
        'hmmer2_home'               => $self->check_dir_in_cellar('hmmer2/2.3.2/bin'),
        'hmmer3_home'               => $self->check_dir_in_cellar('hmmer/3.1b2_1/bin'),
        'codeml_exe'                => $self->check_exe_in_cellar('paml43/4.3.0/bin/codeml'),
        'ktreedist_exe'             => $self->check_exe_in_cellar('ktreedist/1.0.0/bin/Ktreedist.pl'),
        'blast_bin_dir'             => $self->check_dir_in_cellar('blast/2.2.30/bin'),
        'pantherScore_path'         => $self->check_dir_in_cellar('pantherscore/1.03'),
        'cafe_shell'                => $self->check_exe_in_cellar('cafe/2.2/bin/cafeshell'),
        'fasttree_exe'              => $self->check_exe_in_cellar('fasttree/2.1.8/bin/FastTree'),
        'getPatterns_exe'           => $self->check_exe_in_cellar('raxml-get-patterns/1.0/bin/getPatterns'),
        'java_exe'                  => $self->check_exe_in_linuxbrew_opt('jdk@8/bin/java'),
        'cdhit_exe'                 => $self->check_exe_in_cellar('cd-hit/4.6.8/bin/cd-hit'),

        # HMM specific parameters
        # The location of the HMM library:
        'hmm_library_basedir'           => '/hps/nobackup/production/ensembl/compara_ensembl/compara_hmm_91/',
        'hmm_library_name'              => 'compara_hmm_91.hmm3',
        'hmmer_search_cutoff'           => '1e-23',
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         'default'      => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
         '250Mb_job'    => {'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '16Gb_job'     => {'LSF' => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '24Gb_job'     => {'LSF' => '-C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
         '32Gb_job'     => {'LSF' => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         '64Gb_job'     => {'LSF' => '-C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"' },
         '512Gb_job'    => {'LSF' => '-C0 -M512000 -R"select[mem>512000] rusage[mem=512000]"' },

         '8Gb_4c_job'   => {'LSF' => '-n 4 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"' },

         '4Gb_8c_job'   => {'LSF' => '-n 8 -C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]  span[hosts=1]"' },
         '8Gb_8c_job'   => {'LSF' => '-n 8 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"' },
         '16Gb_8c_job'  => {'LSF' => '-n 8 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_8c_job'  => {'LSF' => '-n 8 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },

         '16Gb_16c_job' => {'LSF' => '-n 16 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_16c_job' => {'LSF' => '-n 16 -C0 -M16000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '64Gb_16c_job' => {'LSF' => '-n 16 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"' },

         '16Gb_32c_job' => {'LSF' => '-n 32 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_32c_job' => {'LSF' => '-n 32 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },

         '16Gb_64c_job' => {'LSF' => '-n 64 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_64c_job' => {'LSF' => '-n 64 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '256Gb_64c_job' => {'LSF' => '-n 64 -C0 -M256000 -R"select[mem>256000] rusage[mem=256000] span[hosts=1]"' },

         '8Gb_8c_mpi'   => {'LSF' => '-q mpi-rh7 -n 8  -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=8]"' },
         '8Gb_16c_mpi'  => {'LSF' => '-q mpi-rh7 -n 16 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '8Gb_24c_mpi'  => {'LSF' => '-q mpi-rh7 -n 24 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=12]"' },
         '8Gb_32c_mpi'  => {'LSF' => '-q mpi-rh7 -n 32 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '8Gb_64c_mpi'  => {'LSF' => '-q mpi-rh7 -n 64 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },

         '32Gb_8c_mpi'  => {'LSF' => '-q mpi-rh7 -n 8  -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=8]"' },
         '32Gb_16c_mpi' => {'LSF' => '-q mpi-rh7 -n 16 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },
         '32Gb_24c_mpi' => {'LSF' => '-q mpi-rh7 -n 24 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=12]"' },
         '32Gb_32c_mpi' => {'LSF' => '-q mpi-rh7 -n 32 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },
         '32Gb_64c_mpi' => {'LSF' => '-q mpi-rh7 -n 64 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },

         'msa'          => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         'msa_himem'    => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
    };
}

1;

