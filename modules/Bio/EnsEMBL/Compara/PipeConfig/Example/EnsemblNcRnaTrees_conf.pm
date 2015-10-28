=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Examples::EnsemblNcRnaTrees_conf

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

package Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblNcRnaTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            # User details
            'email'                 => $self->o('ENV', 'USER').'@sanger.ac.uk',

            # Must be given on the command line
            #'mlss_id'          => 40100,
            # Found automatically if the Core API is in PERL5LIB
            #'ensembl_release'          => '76',
            'rel_suffix'       => '',
            'work_dir'         => '/lustre/scratch110/ensembl/' .
                               $self->o('ENV', 'USER') .
                               '/nc_trees_' .
                               $self->o('rel_with_suffix'),

            'pipeline_name'    => 'compara_nctrees_'.$self->o('rel_with_suffix'),


            # tree break
            'treebreak_gene_count'     => 400,

            # capacity values for some analysis:
            'load_members_capacity'           => 10,
            'quick_tree_break_capacity'       => 100,
            'msa_chooser_capacity'            => 200,
            'other_paralogs_capacity'         => 200,
            'merge_supertrees_capacity'       => 200,
            'aligner_for_tree_break_capacity' => 200,
            'infernal_capacity'               => 200,
            'orthotree_capacity'              => 200,
            'treebest_capacity'               => 400,
            'genomic_tree_capacity'           => 300,
            'genomic_alignment_capacity'      => 300,
            'fast_trees_capacity'             => 300,
            'raxml_capacity'                  => 300,
            'recover_capacity'                => 150,
            'ss_picts_capacity'               => 200,

            # Params for healthchecks;
            'hc_priority'                     => 10,
            'hc_capacity'                     => 40,
            'hc_batch_size'                   => 10,

            # executable locations:
            'cmalign_exe'           => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmalign',
            'cmbuild_exe'           => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmbuild',
            'cmsearch_exe'          => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmsearch',
            'mafft_exe'             => '/software/ensembl/compara/mafft-7.221/bin/mafft',
            'raxml_exe'             => '/software/ensembl/compara/raxml/standard-RAxML/raxmlHPC-PTHREADS-SSE3',
            'prank_exe'             => '/software/ensembl/compara/prank/090707/src/prank',
            'raxmlLight_exe'        => '/software/ensembl/compara/raxml/RAxML-Light-1.0.5/raxmlLight-PTHREADS',
            'parsimonator_exe'      => '/software/ensembl/compara/parsimonator/Parsimonator-1.0.2/parsimonator-SSE3',
            'ktreedist_exe'         => '/software/ensembl/compara/ktreedist/Ktreedist.pl',
            'fasttree_exe'          => '/software/ensembl/compara/fasttree/FastTree',
            'treebest_exe'          => '/software/ensembl/compara/treebest',
            'quicktree_exe'         => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
            'r2r_exe'               => '/software/ensembl/compara/R2R-1.0.3/src/r2r',
            'cafe_shell'            => '/software/ensembl/compara/cafe/cafe.2.2/cafe/bin/shell',

            # RFAM parameters
            'rfam_ftp_url'           => 'ftp://ftp.sanger.ac.uk/pub/databases/Rfam/11.0/',
            'rfam_remote_file'       => 'Rfam.cm.gz',
            'rfam_expanded_basename' => 'Rfam.cm',
            'rfam_expander'          => 'gunzip ',

            # CAFE parameters
            'initialise_cafe_pipeline'  => 1,
            'cafe_species'          => ['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus'],

            # Other parameters
            'raxml_number_of_cores' => 4,
            'epo_species_set_name'  => 'mammals',

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

sub resource_classes {
    my ($self) = @_;
    return {
        %{ $self->SUPER::resource_classes() },
            '250Mb_job'               => { 'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
            '500Mb_job'               => { 'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
            '1Gb_job'                 => { 'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
            '2Gb_job'                 => { 'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
            '4Gb_job'                 => { 'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
            '8Gb_job'                 => { 'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },

            '2Gb_ncores_job'          => { 'LSF' => '-C0 -n'. $self->o('raxml_number_of_cores') . ' -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"' },
            '8Gb_ncores_job'          => { 'LSF' => '-C0 -n'. $self->o('raxml_number_of_cores') . ' -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"' },

            # When we grab a machine in the long queue, let's keep it as long as we can
            # this is for other_paralogs
            '250Mb_long_job'          => { 'LSF' => ['-C0 -q long -M250   -R"select[mem>250]   rusage[mem=250]"', '-lifespan 360' ] },
            # this is for fast_trees
            '8Gb_long_ncores_job'     => { 'LSF' => ['-C0 -q long -n'. $self->o('raxml_number_of_cores') . ' -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"', '-lifespan 360' ] },
            # this is for genomic_alignment_basement_himem
            '8Gb_basement_ncores_job' => { 'LSF' => ['-C0 -q basement -n'. $self->o('raxml_number_of_cores') . ' -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"', '-lifespan 2880' ] },
           };
}

1;

