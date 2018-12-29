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
    'base_dir'              => '/hps/nobackup2/production/ensembl/' . $self->o('ENV', 'USER') . '/protein_trees/',

    # the master database for synchronization of various ids (use undef if you don't have a master database)
    'master_db' => 'compara_master',
    'member_db' => 'compara_members',

    # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
    'prev_rel_db' => 'compara_prev',

    # Points to the previous protein trees production database. Will be used for various GOC operations. 
    # Use "undef" if running the pipeline without reuse.
    'goc_reuse_db' => 'ptrees_prev',

    # non-standard executable locations
        'treerecs_exe'              => '/homes/mateus/reconcile/Treerecs/bin/Treerecs',

        # HMM specific parameters
        # HMMer versions could be either 2 or 3
        # The location of the HMM library:

        #HMMER 2
        'hmm_library_version'           => '2',
        'hmm_library_basedir'           => '/hps/nobackup2/production/ensembl/compara_ensembl/treefam_hmms/2019-01-02',

        #HMMER 3
        #'hmm_library_version'       => '3',
        #'hmm_library_basedir'       => '/hps/nobackup2/production/ensembl/compara_ensembl/compara_hmm_91/',
        'hmm_library_name'              => 'compara_hmm_91.hmm3',
        'hmmer_search_cutoff'           => '1e-23',


    };
}


sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         # Most light-weight analyses still neeed 250Mb. It practical to redefine "default" and skip -rc_name
         'default'      => {'LSF' => ['-C0 -M250   -R"select[mem>250]   rusage[mem=250]"', $reg_requirement] },

         '500Mb_job'    => {'LSF' => ['-C0 -M500   -R"select[mem>500]   rusage[mem=500]"',  $reg_requirement] },
         '1Gb_job'      => {'LSF' => ['-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $reg_requirement] },
         '2Gb_job'      => {'LSF' => ['-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement] },
         '4Gb_job'      => {'LSF' => ['-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $reg_requirement] },
         '8Gb_job'      => {'LSF' => ['-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"', $reg_requirement] },
         '16Gb_job'     => {'LSF' => ['-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"', $reg_requirement] },
         '24Gb_job'     => {'LSF' => ['-C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"', $reg_requirement] },
         '32Gb_job'     => {'LSF' => ['-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"', $reg_requirement] },
         '64Gb_job'     => {'LSF' => ['-C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"', $reg_requirement] },
         '512Gb_job'    => {'LSF' => ['-C0 -M512000 -R"select[mem>512000] rusage[mem=512000]"', $reg_requirement] },

         '250Mb_6_hour_job' => {'LSF' => ['-C0 -W 6:00 -M250   -R"select[mem>250]   rusage[mem=250]"',  $reg_requirement] },
         '2Gb_6_hour_job'   => {'LSF' => ['-C0 -W 6:00 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement] },

         '8Gb_4c_job'   => {'LSF' => ['-n 4 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"', $reg_requirement] },
         '32Gb_4c_job'  => {'LSF' => ['-n 4 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },

         '4Gb_8c_job'   => {'LSF' => ['-n 8 -C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]  span[hosts=1]"', $reg_requirement] },
         '8Gb_8c_job'   => {'LSF' => ['-n 8 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"', $reg_requirement] },
         '16Gb_8c_job'  => {'LSF' => ['-n 8 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
         '32Gb_8c_job'  => {'LSF' => ['-n 8 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },

         '16Gb_16c_job' => {'LSF' => ['-n 16 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
         '32Gb_16c_job' => {'LSF' => ['-n 16 -C0 -M16000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },
         '64Gb_16c_job' => {'LSF' => ['-n 16 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"', $reg_requirement] },

         '16Gb_32c_job' => {'LSF' => ['-n 32 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
         '32Gb_32c_job' => {'LSF' => ['-n 32 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },

         '16Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
         '32Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },
         '256Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M256000 -R"select[mem>256000] rusage[mem=256000] span[hosts=1]"', $reg_requirement] },

         '8Gb_8c_mpi'   => {'LSF' => ['-q mpi-rh7 -n 8  -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=8]"', $reg_requirement] },
         '8Gb_16c_mpi'  => {'LSF' => ['-q mpi-rh7 -n 16 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"', $reg_requirement] },
         '8Gb_24c_mpi'  => {'LSF' => ['-q mpi-rh7 -n 24 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=12]"', $reg_requirement] },
         '8Gb_32c_mpi'  => {'LSF' => ['-q mpi-rh7 -n 32 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"', $reg_requirement] },
         '8Gb_64c_mpi'  => {'LSF' => ['-q mpi-rh7 -n 64 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"', $reg_requirement] },

         '32Gb_8c_mpi'  => {'LSF' => ['-q mpi-rh7 -n 8  -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=8]"', $reg_requirement] },
         '32Gb_16c_mpi' => {'LSF' => ['-q mpi-rh7 -n 16 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"', $reg_requirement] },
         '32Gb_24c_mpi' => {'LSF' => ['-q mpi-rh7 -n 24 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=12]"', $reg_requirement] },
         '32Gb_32c_mpi' => {'LSF' => ['-q mpi-rh7 -n 32 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"', $reg_requirement] },
         '32Gb_64c_mpi' => {'LSF' => ['-q mpi-rh7 -n 64 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"', $reg_requirement] },

         'msa'          => {'LSF' => ['-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement] },
         'msa_himem'    => {'LSF' => ['-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"', $reg_requirement] },
    };
}

1;

