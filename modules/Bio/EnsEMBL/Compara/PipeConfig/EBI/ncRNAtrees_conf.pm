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

Bio::EnsEMBL::Compara::PipeConfig::EBI::EnsemblNcRnaTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EnsemblNcRnaTrees_conf -password <your_password> -mlss_id <your_MLSS_id>

=head1 DESCRIPTION

This is the Ensembl PipeConfig for the ncRNAtree pipeline.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::ncRNAtrees_conf;
use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            # User details
            'email'                 => $self->o('ENV', 'USER').'@ebi.ac.uk',

            'pipeline_name' => $self->o('division').'_compara_nctrees_'.$self->o('rel_with_suffix'),
            'work_dir'      => '/hps/nobackup2/production/ensembl/'.$self->o('ENV', 'USER').'/'.$self->o('pipeline_name'),

            'genome_dumps_dir' => '/hps/nobackup2/production/ensembl/compara_ensembl/genome_dumps/'.$self->o('division'),
            'binary_species_tree_input_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.'.$self->o('division').'.branch_len.nw',
            'reg_conf'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/production_reg_'.$self->o('division').'_conf.pl',
            
            'master_db'   => 'compara_master',
            'member_db'   => 'compara_members',
            'prev_rel_db' => 'compara_prev',
            'epo_db'      => 'compara_prev',

            # executable locations:
            'cmalign_exe'           => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmalign'),
            'cmbuild_exe'           => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmbuild'),
            'cmsearch_exe'          => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmsearch'),
            'mafft_exe'             => $self->check_exe_in_cellar('mafft/7.305/bin/mafft'),
            'mpirun_exe'            => $self->check_exe_in_cellar('open-mpi/2.1.1/bin/mpirun'),
            'raxml_pthread_exe_sse3'     => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-SSE3'),
            'raxml_pthread_exe_avx'      => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-AVX'),
            'raxml_exe_sse3'             => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-SSE3'),
            'raxml_exe_avx'              => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-AVX'),
            'prank_exe'             => $self->check_exe_in_cellar('prank/140603/bin/prank'),
            'examl_exe_sse3'        => $self->check_exe_in_cellar('examl/3.0.17/bin/examl'),
            'examl_exe_avx'         => $self->check_exe_in_cellar('examl/3.0.17/bin/examl-AVX'),
            'parse_examl_exe'       => $self->check_exe_in_cellar('examl/3.0.17/bin/parse-examl'),
            'parsimonator_exe'      => $self->check_exe_in_cellar('parsimonator/1.0.2/bin/parsimonator-SSE3'),
            'ktreedist_exe'         => $self->check_exe_in_cellar('ktreedist/1.0.0/bin/Ktreedist.pl'),
            'fasttree_exe'          => $self->check_exe_in_cellar('fasttree/2.1.8/bin/FastTree'),
            'treebest_exe'          => $self->check_exe_in_cellar('treebest/88/bin/treebest'),
            'quicktree_exe'         => $self->check_exe_in_cellar('quicktree/2.1/bin/quicktree'),
            'r2r_exe'               => $self->check_exe_in_cellar('r2r/1.0.5/bin/r2r'),
            'cafe_shell'            => $self->check_exe_in_cellar('cafe/2.2/bin/cafeshell'),

           };
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{ $self->SUPER::resource_classes() },
            'default'   => { 'LSF' => ['-C0 -M100   -R"select[mem>100]   rusage[mem=100]"', $reg_requirement] },
            '250Mb_job' => { 'LSF' => ['-C0 -M250   -R"select[mem>250]   rusage[mem=250]"', $reg_requirement] },
            '1Gb_job'   => { 'LSF' => ['-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $reg_requirement] },
            '2Gb_job'   => { 'LSF' => ['-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement] },
            '4Gb_job'   => { 'LSF' => ['-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $reg_requirement] },
            '16Gb_job'  => { 'LSF' => ['-C0 -M16000  -R"select[mem>16000]  rusage[mem=16000]"', $reg_requirement] },

            '500Mb_2c_job' => { 'LSF' => ['-C0 -n 2 -M500 -R"span[hosts=1] select[mem>500] rusage[mem=500]"', $reg_requirement] },
            '1Gb_4c_job'   => { 'LSF' => ['-C0 -n 4 -M1000 -R"span[hosts=1] select[mem>1000] rusage[mem=1000]"', $reg_requirement] },
            '2Gb_4c_job'   => { 'LSF' => ['-C0 -n 4 -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"', $reg_requirement] },
            '2Gb_8c_job'   => { 'LSF' => ['-C0 -n 8 -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"', $reg_requirement] },
            '8Gb_8c_job'   => { 'LSF' => ['-C0 -n 8 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"', $reg_requirement] },
            '32Gb_8c_job'  => { 'LSF' => ['-C0 -n 8 -M32000 -R"span[hosts=1] select[mem>32000] rusage[mem=32000]"', $reg_requirement] },

            # this is for fast_trees
            '8Gb_mpi_4c_job'  => { 'LSF' => ['-q mpi-rh7 -C0 -n 4 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"', '-lifespan 360' ] },
            '16Gb_mpi_4c_job' => { 'LSF' => ['-q mpi-rh7 -C0 -n 4 -M16000 -R"span[hosts=1] select[mem>16000] rusage[mem=16000]"', '-lifespan 360' ] },
            '32Gb_mpi_4c_job' => { 'LSF' => ['-q mpi-rh7 -C0 -n 4 -M32000 -R"span[hosts=1] select[mem>32000] rusage[mem=32000]"', '-lifespan 360' ] },
        };
}

1;

