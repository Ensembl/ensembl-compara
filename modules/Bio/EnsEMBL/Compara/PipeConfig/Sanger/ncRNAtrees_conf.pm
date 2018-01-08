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

Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblNcRnaTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblNcRnaTrees_conf -password <your_password> -mlss_id <your_MLSS_id>

=head1 DESCRIPTION

This is the Ensembl PipeConfig for the ncRNAtree pipeline.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::ncRNAtrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            # User details
            'email'                 => $self->o('ENV', 'USER').'@sanger.ac.uk',

            
            'work_dir'         => '/lustre/scratch110/ensembl/' .
                               $self->o('ENV', 'USER') .
                               '/nc_trees_' .
                               $self->o('rel_with_suffix'),

            # executable locations:
            'cmalign_exe'           => '/software/ensembl/compara/infernal-1.1.1/src/cmalign',
            'cmbuild_exe'           => '/software/ensembl/compara/infernal-1.1.1/src/cmbuild',
            'cmsearch_exe'          => '/software/ensembl/compara/infernal-1.1.1/src/cmsearch',
            'mafft_exe'             => '/software/ensembl/compara/mafft-7.221/bin/mafft',
            'prank_exe'             => '/software/ensembl/compara/prank/090707/src/prank',
            'raxmlLight_exe'        => '/software/ensembl/compara/raxml/RAxML-Light-1.0.5/raxmlLight-PTHREADS',
            'parsimonator_exe'      => '/software/ensembl/compara/parsimonator/Parsimonator-1.0.2/parsimonator-SSE3',
            'ktreedist_exe'         => '/software/ensembl/compara/ktreedist/Ktreedist.pl',
            'fasttree_exe'          => '/software/ensembl/compara/fasttree/FastTree',
            'treebest_exe'          => '/software/ensembl/compara/treebest',
            'quicktree_exe'         => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
            'r2r_exe'               => '/software/ensembl/compara/R2R-1.0.3/src/r2r',
            'cafe_shell'            => '/software/ensembl/compara/cafe/cafe.2.2/cafe/bin/shell',

           
            'epo_db'                => 'mysql://ensro@compara1/epolc_mammals',

            # connection parameters

            # the production database itself (will be created)
            # it inherits most of the properties from EnsemblGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
            'host' => 'compara3',


            'reg1' => {
                       -host   => 'ens-staging',
                       -port   => 3306,
                       -user   => 'ensro',
                       -pass   => '',
                      },

             'reg2' => {
                        -host   => 'ens-staging2',
                        -port   => 3306,
                        -user   => 'ensro',
                        -pass   => '',
                       },


            'master_db' => {
                            -host   => 'compara1',
                            -port   => 3306,
                            -user   => 'ensro',
                            -pass   => '',
                            -dbname => 'mm14_ensembl_compara_master', # 'mm14_ensembl_compara_master',
                           },

           };
}

1;

