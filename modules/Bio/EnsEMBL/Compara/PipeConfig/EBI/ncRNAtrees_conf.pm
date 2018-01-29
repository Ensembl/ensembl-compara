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

            # Must be given on the command line
            #'mlss_id'          => 40100,
            
            'test_mode' => 1, #set this to 0 if this is production run

            # Found automatically if the Core API is in PERL5LIB
            #'ensembl_release'          => '76',
            'work_dir'         => '/hps/nobackup/production/ensembl/' .
                               $self->o('ENV', 'USER') .
                               '/nc_trees_' .
                               $self->o('rel_with_suffix'),

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

            
            # Other parameters
            'epo_db'                => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_91',

            # connection parameters

            'reg1' => {
                       -host   => 'mysql-ens-sta-1',
                       -port   => '4519',
                       -user   => 'ensro',
                      },

            'master_db' => {
                            -host   => 'mysql-ens-compara-prod-1.ebi.ac.uk',
                            -port   => 4485,
                            -user   => 'ensro',
                            -pass   => '',
                            -dbname => 'ensembl_compara_master',
                           },

           };
}

1;

