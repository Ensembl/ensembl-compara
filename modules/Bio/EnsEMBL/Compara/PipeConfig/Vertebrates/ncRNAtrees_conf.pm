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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::ncRNAtrees_conf -mlss_id <your_MLSS_id> -member_db <url_of_new_member_database> -prev_rel_db <last_production_database_of_this_mlss> -epo_db <most_recent_epo_low_coverage_database>

-epo_db should ideally contain EPO-2X alignments of all the genomes used in the ncRNA-trees. However, due to release coordination considerations, this may not be possible. In this case, you can use the one from the previous release

=head1 EXAMPLES

e96
    # All the databases are defined in the production_reg_conf so the command-line is much simpler
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::ncRNAtrees_conf -mlss_id 40130 $(mysql-ens-compara-prod-3-ensadmin details hive)

e94
    -mlss_id 40122 -member_db $(mysql-ens-compara-prod-2 details url waakanni_load_members_94) -prev_rel_db $(mysql-ens-compara-prod-1 details url ensembl_compara_93) -epo_db $(mysql-ens-compara-prod-1 details url ensembl_compara_93)


=head1 DESCRIPTION

This is the Vertebrates PipeConfig for the ncRNAtree pipeline.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::ncRNAtrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            # Must be given on the command line
            #'mlss_id'          => 40100,
            # Found automatically if the Core API is in PERL5LIB
            #'ensembl_release'          => '76',
            #'rel_suffix' => '',

            'division'      => 'vertebrates',
            'collection'    => 'default',       # The name of the species-set within that division
            'pipeline_name' => $self->o('collection') . '_' . $self->o('division').'_ncrna_trees_'.$self->o('rel_with_suffix'),

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
            'decision_capacity'               => 4,

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

            # miRBase database
            'mirbase_url'           => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/mirbase_22',

            # CAFE parameters
            'initialise_cafe_pipeline'  => 1,
            # Use production names here
            'cafe_species'          => ['danio_rerio', 'taeniopygia_guttata', 'callithrix_jacchus', 'pan_troglodytes', 'homo_sapiens', 'mus_musculus'],

            # Other parameters
            'infernal_mxsize'       => 10000,
    };
} 

1;

