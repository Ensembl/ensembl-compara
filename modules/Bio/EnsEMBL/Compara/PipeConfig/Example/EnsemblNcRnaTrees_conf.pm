
=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved

  This software is distributed under a modified Apache license.
  For license details, please see

  http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Examples::EnsemblNcRnaTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::Ensembl_NcRnaTrees_conf -password <your_password>

=head1 DESCRIPTION

    This is the Ensembl PipeConfig for the ncRNAtree pipeline.

=head1 AUTHORSHIP

  Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

  The rest of the documentation details each of the object methods.
  Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblNcRnaTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            'mlss_id'          => 40089,
            'release'          => '72',
            'rel_suffix'       => '',
            'work_dir'         => '/lustre/scratch110/ensembl/' .
                               $self->o('ENV', 'USER') .
                               '/nc_trees_' .
                               $self->o('rel_with_suffix'),

            'rel_with_suffix'  => $self->o('release').$self->o('rel_suffix'),
            'pipeline_name'    => $self->o('pipeline_basename') . '_' . $self->o('rel_with_suffix'),

            # capacity values for some analysis:
            'quick_tree_break_capacity'       => 100,
            'msa_chooser_capacity'            => 100,
            'other_paralogs_capacity'         => 100,
            'merge_supertrees_capacity'       => 100,
            'aligner_for_tree_break_capacity' => 200,
            'infernal_capacity'               => 200,
            'orthotree_capacity'              => 200,
            'treebest_capacity'               => 400,
            'genomic_tree_capacity'           => 200,
            'genomic_alignment_capacity'      => 200,
            'fast_trees_capacity'             => 200,
            'raxml_capacity'                  => 200,
            'recover_capacity'                => 150,
            'ss_picts_capacity'               => 200,
            'hc_capacity'                     => 4,

            # executable locations:
            'cmalign_exe'           => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmalign',
            'cmbuild_exe'           => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmbuild',
            'cmsearch_exe'          => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmsearch',
            'mafft_exe'             => '/software/ensembl/compara/mafft-7.017/bin/mafft',
            'mafft_binaries'        => '/software/ensembl/compara/mafft-7.017/binaries',
            'raxml_exe'             => '/software/ensembl/compara/raxml/standard-RAxML/raxmlHPC-PTHREADS-SSE3',
            'prank_exe'             => '/software/ensembl/compara/prank/090707/src/prank',
            'raxmlLight_exe'        => '/software/ensembl/compara/raxml/RAxML-Light-1.0.5/raxmlLight',
            'parsimonator_exe'      => '/software/ensembl/compara/parsimonator/Parsimonator-1.0.2/parsimonator-SSE3',
            'ktreedist_exe'         => '/software/ensembl/compara/ktreedist/Ktreedist.pl',
            'fasttree_exe'          => '/software/ensembl/compara/fasttree/FastTree',
            'treebest_exe'          => '/software/ensembl/compara/treebest.doubletracking',
            'sreformat_exe'         => '/software/ensembl/compara/sreformat',
            'quicktree_exe'         => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
            'r2r_exe'               => '/software/ensembl/compara/R2R-1.0.3/src/r2r',

            # Other parameters
            'raxml_number_of_cores' => 2,

            # connection parameters
            'pipeline_db' => {
                              -driver => 'mysql',
                              -host   => 'compara2',
                              -port   => 3306,
                              -user   => 'ensadmin',
                              -pass   => $self->o('password'),
                              -dbname => $ENV{'USER'}.'_compara_nctrees_'.$self->o('rel_with_suffix'),
                             },

            'reg1' => {
                       -host   => 'ens-livemirror',
                       -port   => 3306,
                       -user   => 'ensro',
                       -pass   => '',
                      },

             'reg2' => {
                        -host   => 'ens-livemirror',
                        -port   => 3306,
                        -user   => 'ensro',
                        -pass   => '',
                       },

            'master_db' => {
                            -host   => 'compara1',
                            -port   => 3306,
                            -user   => 'ensro',
                            -pass   => '',
                            -dbname => 'sf5_ensembl_compara_master', # 'sf5_ensembl_compara_master',
                           },

            'epo_db' => {   # ideally, the current release database with epo pipeline results already loaded
                         -host   => 'ens-livemirror',
                         -port   => 3306,
                         -user   => 'ensro',
                         -pass   => '',
                         -dbname => 'ensembl_compara_72',
                        },


           };
}

sub resource_classes {
    my ($self) = @_;
    return {
            'default'      => { 'LSF' => '-M2000 -R"select[mem>2000] rusage[mem=2000]"' },
            '1Gb_job'      => { 'LSF' => '-C0         -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
            '4Gb_job'      => { 'LSF' => '-C0         -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
            '4Gb_long_job' => { 'LSF' => '-C0 -q basement -M4000 -R"select[mem>4000]  rusage[mem=4000]"' },
            '1Gb_long_job' => { 'LSF' => '-C0 -q long -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
            '2Gb_basement' => { 'LSF' => '-C0 -n2 -q basement -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"'},
           };
}

1;

