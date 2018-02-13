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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ncRNAtrees_conf -password <your_password> -mlss_id <your_MLSS_id>

=head1 DESCRIPTION

This is the Ensembl PipeConfig for the ncRNAtree pipeline.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ncRNAtrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            # the production database itself (will be created)
            # it inherits most of the properties from EnsemblGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
            'host' => 'mysql-ens-compara-prod-4',
            'port' => 4401,

            # Must be given on the command line
            #'mlss_id'          => 40100,
            # Found automatically if the Core API is in PERL5LIB
            #'ensembl_release'          => '76',
            'rel_suffix'       => '',

            'pipeline_name'    => 'compara_nctrees_'.$self->o('rel_with_suffix'),


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
            'genomic_alignment_capacity'      => 700,
            'fast_trees_capacity'             => 400,
            'raxml_capacity'                  => 700,
            'recover_capacity'                => 150,
            'ss_picts_capacity'               => 200,
            'ortho_stats_capacity'            => 10,
            'homology_id_mapping_capacity'    => 10,
            'cafe_capacity'                   => 50,

            # Setting priorities
            'genomic_alignment_priority'       => 35,
            'genomic_alignment_himem_priority' => 40,


            # Params for healthchecks;
            'hc_priority'                     => 10,
            'hc_capacity'                     => 40,
            'hc_batch_size'                   => 10,

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
            'infernal_mxsize'       => 10000,

            # For the homology_id_mapping
            'prev_rel_db'  => "mysql://ensro\@mysql-ens-compara-prod-1:4485/ensembl_compara_91",
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
            '16Gb_job'                 => { 'LSF' => '-C0 -M16000  -R"select[mem>16000]  rusage[mem=16000]"' },
            '32Gb_job'                 => { 'LSF' => '-C0 -M32000  -R"select[mem>32000]  rusage[mem=32000]"' },

            '2Gb_4c_job'          => { 'LSF' => '-C0 -n 4 -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"' },
            '8Gb_4c_job'          => { 'LSF' => '-C0 -n 4 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"' },
            '4Gb_8c_job'          => { 'LSF' => '-C0 -n 8 -M4000 -R"span[hosts=1] select[mem>4000] rusage[mem=4000]"' },
            '8Gb_16c_job'         => { 'LSF' => '-C0 -n 16 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"' },
            '8Gb_8c_job'          => { 'LSF' => '-C0 -n 8 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"' },
            '32Gb_4c_job'         => { 'LSF' => '-C0 -n 4 -M32000 -R"span[hosts=1] select[mem>32000] rusage[mem=32000]"' },
            '32Gb_8c_job'         => { 'LSF' => '-C0 -n 8 -M32000 -R"span[hosts=1] select[mem>32000] rusage[mem=32000]"' },

            # When we grab a machine in the long queue, let's keep it as long as we can
            # this is for other_paralogs
            '250Mb_long_job'          => { 'LSF' => ['-C0 -M250 -R"select[mem>250]   rusage[mem=250]"', '-lifespan 360' ] },
            # this is for fast_trees
            '8Gb_mpi_4c_job'     => { 'LSF' => ['-q mpi-rh7 -C0 -n 4 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"', '-lifespan 360' ] },
            '16Gb_mpi_4c_job'    => { 'LSF' => ['-q mpi-rh7 -C0 -n 4 -M16000 -R"span[hosts=1] select[mem>16000] rusage[mem=16000]"', '-lifespan 360' ] },
            '32Gb_mpi_4c_job'    => { 'LSF' => ['-q mpi-rh7 -C0 -n 4 -M32000 -R"span[hosts=1] select[mem>32000] rusage[mem=32000]"', '-lifespan 360' ] },
           };
}

1;

