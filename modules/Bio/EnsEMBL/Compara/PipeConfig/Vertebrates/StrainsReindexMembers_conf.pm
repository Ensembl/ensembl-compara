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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsReindexMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsReindexMembers_conf -collection <collection> -member_type <protein|ncrna>

=head1 EXAMPLES

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsReindexMembers_conf ...

e99  # From now on the collection and member_type parameters are only used to name the database, mlss_id is not needed any more
    -prev_tree_db murinae_ptrees_prev  -collection murinae -member_type protein
    -prev_tree_db murinae_nctrees_prev -collection murinae -member_type ncrna
    -prev_tree_db sus_ptrees_prev      -collection sus     -member_type protein
    -prev_tree_db sus_nctrees_prev     -collection sus     -member_type ncrna

e98 protein-trees
    -mlss_id 40128 -member_type ncrna   -prev_rel_db murinae_nctrees_prev $(mysql-ens-compara-prod-7-ensadmin details hive)
e98 ncRNA-trees
    -mlss_id 40126 -member_type protein -prev_rel_db murinae_ptrees_prev  $(mysql-ens-compara-prod-7-ensadmin details hive)

e94 protein-trees
    -mlss_id 40111 -member_type protein -member_db $(mysql-ens-compara-prod-2 details url waakanni_load_members_94) -prev_rel_db $(mysql-ens-compara-prod-1 details url mateus_murinae_protein_trees_93) $(mysql-ens-compara-prod-1-ensadmin details hive)
e94 ncRNA-trees
    -mlss_id 40112 -member_type ncrna -member_db $(mysql-ens-compara-prod-2 details url waakanni_load_members_94) -prev_rel_db $(mysql-ens-compara-prod-1 details url mateus_murinae_ncrna_trees_93) $(mysql-ens-compara-prod-1-ensadmin details hive)

e93 protein-trees
    -mlss_id 40111 -member_type protein -member_db $(mysql-ens-compara-prod-2 details url mateus_load_members_93) -prev_rel_db $(mysql-ens-compara-prod-3 details url carlac_murinae_reindex_protein_92)
e93 ncRNA-trees
    -mlss_id 40112 -member_type ncrna -member_db $(mysql-ens-compara-prod-2 details url mateus_load_members_93) -prev_rel_db $(mysql-ens-compara-prod-2 details url muffato_murinae_ncrna_trees_92)

e91 protein-trees
    -mlss_id 40111 -member_type protein -member_db $(mysql-ens-compara-prod-2 details url mateus_load_members_91) -prev_rel_db $(mysql-ens-compara-prod-3 details url carlac_murinae_protein_trees_90)
e91 ncRNA-trees
    -mlss_id 40112 -member_type ncrna -member_db $(mysql-ens-compara-prod-2 details url mateus_load_members_91) -prev_rel_db $(mysql-ens-compara-prod-4 details url mateus_murinae_nctrees_90)

=head1 DESCRIPTION

A specialized version of ReindexMembers_conf to use in Vertebrates for
the mouse-strains, although "murinae" is only used to set up the
pipeline name.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsReindexMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'      => 'vertebrates',

        # Main capacity for the pipeline
        'copy_capacity'                 => 4,

        # Params for healthchecks;
        'hc_capacity'                     => 40,
        'hc_batch_size'                   => 10,

        # Where to find the shared databases (use URLs or registry names)
        'master_db' => 'compara_master',
        'member_db' => 'compara_members',
    };
}


1;
