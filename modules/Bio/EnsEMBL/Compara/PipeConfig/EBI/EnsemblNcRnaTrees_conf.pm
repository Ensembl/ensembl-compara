=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EnsemblNcRnaTrees_conf;
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

            # tree break
            'treebreak_gene_count'     => 400,

            # capacity values for some analysis:
            'load_members_capacity'           => 10,
            'quick_tree_break_capacity'       => 100,
            'msa_chooser_capacity'            => 200,
            'other_paralogs_capacity'         => 200,
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
            'ortho_stats_capacity'            => 10,
            'homology_dNdS_capacity'          => 10,

            # Params for healthchecks;
            'hc_priority'                     => 10,
            'hc_capacity'                     => 40,
            'hc_batch_size'                   => 10,

            # executable locations:
            'cmalign_exe'           => $self->o('ensembl_cellar').'/infernal/1.1.1/bin/cmalign',
            'cmbuild_exe'           => $self->o('ensembl_cellar').'/infernal/1.1.1/bin/cmbuild',
            'cmsearch_exe'          => $self->o('ensembl_cellar').'/infernal/1.1.1/bin/cmsearch',
            'mafft_exe'             => $self->o('ensembl_cellar').'/mafft/7.305/bin/mafft',

            'raxml_pthread_exe_sse3'     => $self->o('ensembl_cellar').'/raxml/8.2.8/bin/raxmlHPC-PTHREADS-SSE3',
            'raxml_pthread_exe_avx'      => $self->o('ensembl_cellar').'/raxml/8.2.8/bin/raxmlHPC-PTHREADS-AVX',
            'raxml_exe_sse3'             => $self->o('ensembl_cellar').'/raxml/8.2.8/bin/raxmlHPC-SSE3',
            'raxml_exe_avx'              => $self->o('ensembl_cellar').'/raxml/8.2.8/bin/raxmlHPC-AVX',
            'prank_exe'             => $self->o('ensembl_cellar').'/prank/140603/bin/prank',
            'examl_exe_sse3'        => $self->o('ensembl_cellar').'/examl/3.0.17/bin/examl',
            'examl_exe_avx'         => $self->o('ensembl_cellar').'/examl/3.0.17/bin/examl-AVX',
            'parse_examl_exe'       => $self->o('ensembl_cellar').'/examl/3.0.17/bin/parse-examl',
            'parsimonator_exe'      => $self->o('ensembl_cellar').'/parsimonator/1.0.2/bin/parsimonator-SSE3',
            'ktreedist_exe'         => $self->o('ensembl_cellar').'/ktreedist/1.0.0/bin/Ktreedist.pl',
            'fasttree_exe'          => $self->o('ensembl_cellar').'/fasttree/2.1.8/bin/FastTree',
            'treebest_exe'          => $self->o('ensembl_cellar').'/treebest/88/bin/treebest',
            'quicktree_exe'         => $self->o('ensembl_cellar').'/quicktree/1.1.0/bin/quicktree',
            'r2r_exe'               => $self->o('ensembl_cellar').'/r2r/1.0.4/bin/r2r',
            'cafe_shell'            => $self->o('ensembl_cellar').'/cafe/2.2/bin/cafeshell',

            # RFAM parameters
            'rfam_ftp_url'           => 'ftp://ftp.ebi.ac.uk/pub/databases/Rfam/12.0/',
            'rfam_remote_file'       => 'Rfam.cm.gz',
            'rfam_expanded_basename' => 'Rfam.cm',
            'rfam_expander'          => 'gunzip ',

            # CAFE parameters
            'initialise_cafe_pipeline'  => 1,
            # Use production names here
            'cafe_species'          => ['danio_rerio', 'taeniopygia_guttata', 'callithrix_jacchus', 'pan_troglodytes', 'homo_sapiens', 'mus_musculus'],

            # Other parameters
            'raxml_number_of_cores' => 4,
            'epo_db'                => 'mysql://ensro@mysql-ens-compara-prod-3.ebi.ac.uk:4523/carlac_EPO_low_mammals_86',
            'production_db_url'     => 'mysql://ensro@mysql-ens-sta-1:4519/ensembl_production',

            # connection parameters

            # the production database itself (will be created)
            # it inherits most of the properties from EnsemblGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
            #'host' => 'mysql-treefam-prod:4401',


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
            '8Gb_long_job'                 => { 'LSF' => '-C0 -q long -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
            '16Gb_job'                 => { 'LSF' => '-C0 -M16000  -R"select[mem>16000]  rusage[mem=16000]"' },

            '2Gb_ncores_job'          => { 'LSF' => '-C0 -n'. $self->o('raxml_number_of_cores') . ' -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"' },
            '8Gb_ncores_job'          => { 'LSF' => '-C0 -n'. $self->o('raxml_number_of_cores') . ' -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"' },
            '32Gb_ncores_job'         => { 'LSF' => '-C0 -n'. $self->o('raxml_number_of_cores') . ' -M32000 -R"span[hosts=1] select[mem>32000] rusage[mem=32000]"' },

            # When we grab a machine in the long queue, let's keep it as long as we can
            # this is for other_paralogs
            '250Mb_long_job'          => { 'LSF' => ['-C0  -M250   -R"select[mem>250]   rusage[mem=250]"', '-lifespan 360' ] },
            # this is for fast_trees
            '8Gb_long_ncores_job'     => { 'LSF' => ['-q mpi-rh7 -n'. $self->o('raxml_number_of_cores') . ' -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=' . $self->o('raxml_number_of_cores') . ' ]"'] },
            '32Gb_long_ncores_job'    => { 'LSF' => ['-q mpi-rh7 -n'. $self->o('raxml_number_of_cores') . ' -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=' . $self->o('raxml_number_of_cores') . ' ]"' ] },
           };
}

1;

